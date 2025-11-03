// ignore_for_file: sort_constructors_first

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

/// Network retry strategies with exponential backoff.
///
/// This module provides robust retry mechanisms for network operations,
/// particularly useful for mobile environments where connections can be
/// unreliable.
///
/// **Benefits**:
/// - 🔄 Automatic retries on transient failures
/// - 📶 Adapts to network conditions
/// - 🔋 Battery efficient with exponential backoff
/// - 📱 Mobile-optimized for flaky connections

/// Configuration for retry behavior.
class RetryConfig {
  /// Creates a retry configuration.
  const RetryConfig({
    this.maxRetries = 5,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitter = 0.1,
  });

  /// Maximum number of retry attempts.
  ///
  /// Default is 5 retries, giving 6 total attempts (1 initial + 5 retries).
  final int maxRetries;

  /// Base delay before first retry.
  ///
  /// Default is 1 second. Each retry doubles this (exponential backoff):
  /// - Attempt 1: 1s
  /// - Attempt 2: 2s
  /// - Attempt 3: 4s
  /// - Attempt 4: 8s
  /// - Attempt 5: 16s
  final Duration baseDelay;

  /// Maximum delay between retries.
  ///
  /// Caps the exponential backoff to prevent excessively long waits.
  /// Default is 30 seconds.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  ///
  /// Default is 2.0 (doubles each time). Can be adjusted:
  /// - 1.5 for gentler backoff
  /// - 3.0 for more aggressive backoff
  final double multiplier;

  /// Random jitter factor (0.0 to 1.0).
  ///
  /// Adds randomness to prevent thundering herd problem where multiple
  /// clients retry simultaneously. Default is 0.1 (±10% jitter).
  final double jitter;

  /// Creates a copy with optional overrides.
  RetryConfig copyWith({
    int? maxRetries,
    Duration? baseDelay,
    Duration? maxDelay,
    double? multiplier,
    double? jitter,
  }) =>
      RetryConfig(
        maxRetries: maxRetries ?? this.maxRetries,
        baseDelay: baseDelay ?? this.baseDelay,
        maxDelay: maxDelay ?? this.maxDelay,
        multiplier: multiplier ?? this.multiplier,
        jitter: jitter ?? this.jitter,
      );
}

/// Exception indicating all retry attempts have been exhausted.
class RetryExhaustedException implements Exception {
  /// Creates a retry exhausted exception.
  const RetryExhaustedException({
    required this.attempts,
    required this.lastError,
  });

  /// Number of attempts made (including initial attempt).
  final int attempts;

  /// The last error encountered.
  final Object lastError;

  @override
  String toString() =>
      'RetryExhaustedException: Failed after $attempts attempts. '
      'Last error: $lastError';
}

/// Retry strategy with exponential backoff and jitter.
///
/// Automatically retries failed operations with increasing delays between
/// attempts. Useful for network operations, API calls, and database queries.
///
/// **Usage**:
/// ```dart
/// final retry = ExponentialBackoffRetry();
///
/// final result = await retry.execute(() async {
///   return await http.get('https://api.storacha.network/status');
/// });
/// ```
class ExponentialBackoffRetry {
  /// Creates an exponential backoff retry strategy.
  ExponentialBackoffRetry({
    RetryConfig? config,
  }) : config = config ?? const RetryConfig();

  /// Retry configuration.
  final RetryConfig config;

  /// Executes an action with automatic retries on failure.
  ///
  /// [action] - The async function to execute
  /// [shouldRetry] - Optional predicate to determine if error is retryable
  ///                 (default: retry on all errors)
  /// [onRetry] - Optional callback invoked before each retry attempt
  ///
  /// Returns the result of [action] if successful.
  /// Throws [RetryExhaustedException] if all attempts fail.
  ///
  /// Example:
  /// ```dart
  /// final data = await retry.execute(
  ///   () => api.fetchData(),
  ///   shouldRetry: (error) => error is NetworkException,
  ///   onRetry: (attempt, delay) {
  ///     print('Retry $attempt after ${delay.inSeconds}s...');
  ///   },
  /// );
  /// ```
  Future<T> execute<T>(
    Future<T> Function() action, {
    bool Function(Object)? shouldRetry,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    var attempt = 0;
    Object? lastError;

    while (attempt <= config.maxRetries) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        attempt++;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // Check if we've exhausted retries
        if (attempt > config.maxRetries) {
          throw RetryExhaustedException(
            attempts: attempt,
            lastError: error,
          );
        }

        // Calculate delay with exponential backoff and jitter
        final delay = _calculateDelay(attempt);

        // Notify before retry
        onRetry?.call(attempt, delay);

        // Wait before retrying
        await Future<void>.delayed(delay);
      }
    }

    // Should never reach here, but satisfy analyzer
    throw RetryExhaustedException(
      attempts: attempt,
      lastError: lastError ?? 'Unknown error',
    );
  }

  /// Calculates the delay before the next retry attempt.
  ///
  /// Uses exponential backoff: baseDelay * (multiplier ^ (attempt - 1))
  /// Adds random jitter to prevent thundering herd.
  /// Caps at maxDelay to prevent excessively long waits.
  Duration _calculateDelay(int attempt) {
    // Exponential backoff: baseDelay * multiplier^(attempt-1)
    final exponent = attempt - 1;
    final exponentialMs =
        (config.baseDelay.inMilliseconds * math.pow(config.multiplier, exponent))
            .toInt();

    // Add jitter: ±(jitter * delay)
    final jitterRange = (exponentialMs * config.jitter).toInt();
    final random = (DateTime.now().millisecond / 1000) - 0.5; // -0.5 to 0.5
    final jitterMs = exponentialMs + (jitterRange * 2 * random).toInt();

    // Cap at maxDelay
    final cappedMs = jitterMs.clamp(0, config.maxDelay.inMilliseconds);

    return Duration(milliseconds: cappedMs);
  }
}

/// Preset configurations for common retry scenarios.
class RetryPresets {
  RetryPresets._(); // Prevent instantiation

  /// Ultra-fast retry for parallel uploads with minimal latency.
  ///
  /// - Max retries: 2
  /// - Base delay: 200ms
  /// - Max delay: 2s
  /// - Total time: ~2.5s max
  /// - Use for parallel upload operations where speed is critical
  static const ultraFast = RetryConfig(
    maxRetries: 2,
    baseDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 2),
  );

  /// Fast retry for quickly recovering from transient errors.
  ///
  /// - Max retries: 3
  /// - Base delay: 500ms
  /// - Max delay: 5s
  /// - Total time: ~7.5s max
  static const fast = RetryConfig(
    maxRetries: 3,
    baseDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 5),
  );

  /// Standard retry for general network operations.
  ///
  /// - Max retries: 5
  /// - Base delay: 1s
  /// - Max delay: 30s
  /// - Total time: ~63s max
  static const standard = RetryConfig(
    maxRetries: 5,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
  );

  /// Aggressive retry for critical operations.
  ///
  /// - Max retries: 10
  /// - Base delay: 2s
  /// - Max delay: 60s
  /// - Total time: ~2 minutes max
  static const aggressive = RetryConfig(
    maxRetries: 10,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 60),
  );

  /// Gentle retry for rate-limited APIs.
  ///
  /// - Max retries: 3
  /// - Base delay: 5s
  /// - Max delay: 60s
  /// - Multiplier: 1.5 (gentler growth)
  static const rateLimited = RetryConfig(
    maxRetries: 3,
    baseDelay: Duration(seconds: 5),
    maxDelay: Duration(seconds: 60),
    multiplier: 1.5,
  );
}

/// Helper for common retry scenarios.
extension RetryHelpers on ExponentialBackoffRetry {
  /// Retries a network request with standard configuration.
  ///
  /// Automatically retries on common network errors.
  static Future<T> networkRequest<T>(
    Future<T> Function() request, {
    RetryConfig config = RetryPresets.standard,
    void Function(int, Duration)? onRetry,
  }) async {
    final retry = ExponentialBackoffRetry(config: config);

    return await retry.execute(
      request,
      shouldRetry: (error) {
        // Retry on common network errors
        return error is SocketException ||
            error is TimeoutException ||
            error is HttpException ||
            error.toString().contains('Network') ||
            error.toString().contains('Connection');
      },
      onRetry: onRetry,
    );
  }
}

