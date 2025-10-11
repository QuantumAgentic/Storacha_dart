import 'dart:async';
import 'dart:io';

import 'package:storacha_dart/src/core/network_retry.dart';
import 'package:test/test.dart';

void main() {
  group('RetryConfig', () {
    test('creates with defaults', () {
      const config = RetryConfig();

      expect(config.maxRetries, equals(5));
      expect(config.baseDelay, equals(const Duration(seconds: 1)));
      expect(config.maxDelay, equals(const Duration(seconds: 30)));
      expect(config.multiplier, equals(2.0));
      expect(config.jitter, equals(0.1));
    });

    test('creates with custom values', () {
      const config = RetryConfig(
        maxRetries: 3,
        baseDelay: Duration(milliseconds: 500),
        maxDelay: Duration(seconds: 10),
        multiplier: 1.5,
        jitter: 0.2,
      );

      expect(config.maxRetries, equals(3));
      expect(config.baseDelay, equals(const Duration(milliseconds: 500)));
      expect(config.maxDelay, equals(const Duration(seconds: 10)));
      expect(config.multiplier, equals(1.5));
      expect(config.jitter, equals(0.2));
    });

    test('copyWith preserves unmodified values', () {
      const original = RetryConfig(maxRetries: 3);
      final copied = original.copyWith(baseDelay: const Duration(seconds: 2));

      expect(copied.maxRetries, equals(3)); // Preserved
      expect(copied.baseDelay, equals(const Duration(seconds: 2))); // Changed
      expect(copied.maxDelay, equals(const Duration(seconds: 30))); // Preserved
    });

    test('copyWith allows overriding all values', () {
      const original = RetryConfig();
      final copied = original.copyWith(
        maxRetries: 10,
        baseDelay: const Duration(seconds: 5),
        maxDelay: const Duration(seconds: 60),
        multiplier: 3.0,
        jitter: 0.5,
      );

      expect(copied.maxRetries, equals(10));
      expect(copied.baseDelay, equals(const Duration(seconds: 5)));
      expect(copied.maxDelay, equals(const Duration(seconds: 60)));
      expect(copied.multiplier, equals(3.0));
      expect(copied.jitter, equals(0.5));
    });
  });

  group('RetryExhaustedException', () {
    test('creates with attempts and error', () {
      final exception = RetryExhaustedException(
        attempts: 6,
        lastError: 'Connection timeout',
      );

      expect(exception.attempts, equals(6));
      expect(exception.lastError, equals('Connection timeout'));
    });

    test('toString provides useful message', () {
      final exception = RetryExhaustedException(
        attempts: 3,
        lastError: SocketException('Network unreachable'),
      );

      final message = exception.toString();

      expect(message, contains('RetryExhaustedException'));
      expect(message, contains('3 attempts'));
      expect(message, contains('Network unreachable'));
    });
  });

  group('ExponentialBackoffRetry', () {
    test('succeeds on first attempt without retries', () async {
      final retry = ExponentialBackoffRetry();
      var attempts = 0;

      final result = await retry.execute(() async {
        attempts++;
        return 'success';
      });

      expect(result, equals('success'));
      expect(attempts, equals(1));
    });

    test('retries on failure and eventually succeeds', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      var attempts = 0;

      final result = await retry.execute(() async {
        attempts++;
        if (attempts < 3) {
          throw SocketException('Connection failed');
        }
        return 'success on attempt $attempts';
      });

      expect(result, equals('success on attempt 3'));
      expect(attempts, equals(3));
    });

    test('throws RetryExhaustedException when all retries fail', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 2,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      var attempts = 0;

      expect(
        retry.execute(() async {
          attempts++;
          throw SocketException('Always fails');
        }),
        throwsA(isA<RetryExhaustedException>()),
      );

      // Wait for execution
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(attempts, equals(3)); // 1 initial + 2 retries
    });

    test('respects shouldRetry predicate', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 5,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      var attempts = 0;

      // Should NOT retry on ArgumentError
      expect(
        retry.execute(
          () async {
            attempts++;
            throw ArgumentError('Invalid input');
          },
          shouldRetry: (error) => error is SocketException,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(attempts, equals(1)); // No retries
    });

    test('calls onRetry callback with correct parameters', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 2,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      final retryAttempts = <int>[];
      final retryDelays = <Duration>[];

      var attempts = 0;

      await retry.execute(
        () async {
          attempts++;
          if (attempts < 3) {
            throw SocketException('Retry me');
          }
          return 'success';
        },
        onRetry: (attempt, delay) {
          retryAttempts.add(attempt);
          retryDelays.add(delay);
        },
      );

      expect(retryAttempts, equals([1, 2]));
      expect(retryDelays.length, equals(2));
      // Delays should be in the ballpark (with jitter)
      expect(retryDelays[0].inMilliseconds, greaterThan(5));
      expect(retryDelays[0].inMilliseconds, lessThan(20));
    });

    test('delay grows exponentially', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 100),
          jitter: 0.0, // No jitter for predictable testing
        ),
      );

      final delays = <int>[];
      var attempts = 0;

      await retry.execute(
        () async {
          attempts++;
          if (attempts < 4) {
            throw SocketException('Retry');
          }
          return 'ok';
        },
        onRetry: (attempt, delay) {
          delays.add(delay.inMilliseconds);
        },
      );

      // With multiplier 2.0 and baseDelay 100ms:
      // Attempt 1: 100ms * 2^0 = 100ms
      // Attempt 2: 100ms * 2^1 = 200ms
      // Attempt 3: 100ms * 2^2 = 400ms
      expect(delays.length, equals(3));
      expect(delays[0], closeTo(100, 10));
      expect(delays[1], closeTo(200, 20));
      expect(delays[2], closeTo(400, 40));
    });

    test('respects maxDelay cap', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 100),
          maxDelay: Duration(milliseconds: 150),
          jitter: 0.0,
        ),
      );

      final delays = <int>[];
      var attempts = 0;

      await retry.execute(
        () async {
          attempts++;
          if (attempts < 4) {
            throw SocketException('Keep retrying');
          }
          return 'done';
        },
        onRetry: (attempt, delay) {
          delays.add(delay.inMilliseconds);
        },
      );

      // With baseDelay=100ms, multiplier=2.0, maxDelay=150ms:
      // Attempt 1: 100 * 2^0 = 100ms (OK)
      // Attempt 2: 100 * 2^1 = 200ms -> capped to 150ms
      // Attempt 3: 100 * 2^2 = 400ms -> capped to 150ms
      expect(delays[0], lessThanOrEqualTo(150));
      expect(delays[1], lessThanOrEqualTo(150));
      expect(delays[2], lessThanOrEqualTo(150));
    });
  });

  group('RetryPresets', () {
    test('fast preset has correct values', () {
      const preset = RetryPresets.fast;

      expect(preset.maxRetries, equals(3));
      expect(preset.baseDelay, equals(const Duration(milliseconds: 500)));
      expect(preset.maxDelay, equals(const Duration(seconds: 5)));
    });

    test('standard preset has correct values', () {
      const preset = RetryPresets.standard;

      expect(preset.maxRetries, equals(5));
      expect(preset.baseDelay, equals(const Duration(seconds: 1)));
      expect(preset.maxDelay, equals(const Duration(seconds: 30)));
    });

    test('aggressive preset has correct values', () {
      const preset = RetryPresets.aggressive;

      expect(preset.maxRetries, equals(10));
      expect(preset.baseDelay, equals(const Duration(seconds: 2)));
      expect(preset.maxDelay, equals(const Duration(seconds: 60)));
    });

    test('rateLimited preset has correct values', () {
      const preset = RetryPresets.rateLimited;

      expect(preset.maxRetries, equals(3));
      expect(preset.baseDelay, equals(const Duration(seconds: 5)));
      expect(preset.maxDelay, equals(const Duration(seconds: 60)));
      expect(preset.multiplier, equals(1.5));
    });
  });

  group('RetryHelpers', () {
    test('networkRequest retries on SocketException', () async {
      var attempts = 0;

      final result = await RetryHelpers.networkRequest(
        () async {
          attempts++;
          if (attempts < 2) {
            throw SocketException('Network error');
          }
          return 'success';
        },
        config: const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result, equals('success'));
      expect(attempts, equals(2));
    });

    test('networkRequest retries on TimeoutException', () async {
      var attempts = 0;

      final result = await RetryHelpers.networkRequest(
        () async {
          attempts++;
          if (attempts < 2) {
            throw TimeoutException('Request timeout');
          }
          return 'success';
        },
        config: const RetryConfig(
          maxRetries: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result, equals('success'));
      expect(attempts, equals(2));
    });

    test('networkRequest does not retry on ArgumentError', () async {
      var attempts = 0;

      expect(
        RetryHelpers.networkRequest(
          () async {
            attempts++;
            throw ArgumentError('Bad argument');
          },
          config: const RetryConfig(
            maxRetries: 3,
            baseDelay: Duration(milliseconds: 10),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(attempts, equals(1)); // No retries
    });

    test('networkRequest calls onRetry callback', () async {
      final retryLogs = <String>[];
      var attempts = 0;

      await RetryHelpers.networkRequest(
        () async {
          attempts++;
          if (attempts < 3) {
            throw SocketException('Retry');
          }
          return 'done';
        },
        config: const RetryConfig(
          maxRetries: 5,
          baseDelay: Duration(milliseconds: 10),
        ),
        onRetry: (attempt, delay) {
          retryLogs.add('Retry $attempt after ${delay.inMilliseconds}ms');
        },
      );

      expect(retryLogs.length, equals(2));
      expect(retryLogs[0], contains('Retry 1'));
      expect(retryLogs[1], contains('Retry 2'));
    });
  });

  group('Integration: Real-world scenarios', () {
    test('handles flaky network with eventual success', () async {
      final retry = ExponentialBackoffRetry(
        config: RetryPresets.fast,
      );

      var attempts = 0;
      final errors = <String>[];

      final result = await retry.execute(
        () async {
          attempts++;
          switch (attempts) {
            case 1:
              throw SocketException('Network unreachable');
            case 2:
              throw TimeoutException('Request timeout');
            case 3:
              return 'success';
            default:
              throw StateError('Unexpected');
          }
        },
        onRetry: (attempt, delay) {
          errors.add('Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms');
        },
      );

      expect(result, equals('success'));
      expect(attempts, equals(3));
      expect(errors.length, equals(2));
    });

    test('fails fast on non-retryable errors', () async {
      final retry = ExponentialBackoffRetry();
      var attempts = 0;

      expect(
        retry.execute(
          () async {
            attempts++;
            throw FormatException('Invalid JSON');
          },
          shouldRetry: (error) =>
              error is SocketException || error is TimeoutException,
        ),
        throwsA(isA<FormatException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(attempts, equals(1)); // Immediate failure
    });

    test('handles intermittent failures gracefully', () async {
      final retry = ExponentialBackoffRetry(
        config: const RetryConfig(
          maxRetries: 5,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      var attempts = 0;
      final successAttempt = 4;

      final result = await retry.execute(() async {
        attempts++;
        if (attempts < successAttempt) {
          throw SocketException('Intermittent failure $attempts');
        }
        return 'recovered';
      });

      expect(result, equals('recovered'));
      expect(attempts, equals(successAttempt));
    });
  });
}

