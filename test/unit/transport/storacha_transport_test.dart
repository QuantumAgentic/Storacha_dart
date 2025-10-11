import 'dart:typed_data';

import 'package:storacha_dart/src/core/network_retry.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/transport/storacha_transport.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';
import 'package:test/test.dart';

void main() {
  group('StorachaException', () {
    test('creates exception with message', () {
      final exception = StorachaException('Test error');

      expect(exception.message, equals('Test error'));
      expect(exception.code, isNull);
      expect(exception.details, isNull);
    });

    test('creates exception with code and details', () {
      final exception = StorachaException(
        'Test error',
        code: 'ERR_TEST',
        details: {'key': 'value'},
      );

      expect(exception.message, equals('Test error'));
      expect(exception.code, equals('ERR_TEST'));
      expect(exception.details, containsPair('key', 'value'));
    });

    test('toString includes all information', () {
      final exception = StorachaException(
        'Test error',
        code: 'ERR_TEST',
        details: {'key': 'value'},
      );

      final str = exception.toString();
      expect(str, contains('Test error'));
      expect(str, contains('ERR_TEST'));
      expect(str, contains('key'));
    });
  });

  group('StorachaTransport', () {
    test('creates transport with default endpoint', () {
      final transport = StorachaTransport();

      expect(transport.endpoint, equals('https://up.storacha.network'));
    });

    test('creates transport with custom endpoint', () {
      final transport = StorachaTransport(
        endpoint: 'https://custom.endpoint',
      );

      expect(transport.endpoint, equals('https://custom.endpoint'));
    });

    test('creates transport with custom retry config', () {
      final transport = StorachaTransport(
        retryConfig: RetryPresets.fast,
      );

      expect(transport.retryConfig, equals(RetryPresets.fast));
    });

    test('can be closed', () {
      final transport = StorachaTransport();
      expect(() => transport.close(), returnsNormally);
    });
  });

  group('BlobAllocation', () {
    test('fromJson parses allocation with site', () {
      final json = {
        'allocated': true,
        'site': {
          'url': 'https://example.com/upload',
          'headers': {'Authorization': 'Bearer token'},
        },
      };

      final allocation = BlobAllocation.fromJson(json);

      expect(allocation.allocated, isTrue);
      expect(allocation.url, equals('https://example.com/upload'));
      expect(allocation.headers?['Authorization'], equals('Bearer token'));
    });

    test('fromJson parses allocation without site', () {
      final json = {'allocated': false};

      final allocation = BlobAllocation.fromJson(json);

      expect(allocation.allocated, isFalse);
      expect(allocation.url, isNull);
      expect(allocation.headers, isNull);
    });
  });

  group('BlobDescriptor', () {
    test('toJson encodes digest and size', () {
      final descriptor = BlobDescriptor(
        digest: Uint8List.fromList([1, 2, 3, 4]),
        size: 1024,
      );

      final json = descriptor.toJson();

      expect(json['digest'], equals(descriptor.digest));
      expect(json['size'], equals(1024));
    });
  });

  group('InvocationBuilder Integration', () {
    late Signer signer;
    late InvocationBuilder builder;

    setUp(() async {
      signer = await Ed25519Signer.generate();
      builder = InvocationBuilder(signer: signer);
    });

    test('can build space/blob/add invocation', () {
      final capability = Capability(
        with_: 'did:key:space123',
        can: 'space/blob/add',
        nb: {
          'blob': {
            'digest': Uint8List.fromList([1, 2, 3]),
            'size': 100,
          },
        },
      );

      builder.addCapability(capability);
      final invocation = builder.build();

      expect(invocation.capabilities, hasLength(1));
      expect(invocation.capabilities.first.can, equals('space/blob/add'));
    });

    test('can build upload/add invocation', () {
      final capability = Capability(
        with_: 'did:key:space123',
        can: 'upload/add',
        nb: {
          'root': {'/':{' bytes': 'cid_bytes'}},
          'shards': <dynamic>[],
        },
      );

      builder.addCapability(capability);
      final invocation = builder.build();

      expect(invocation.capabilities, hasLength(1));
      expect(invocation.capabilities.first.can, equals('upload/add'));
    });
  });

  // Note: Real HTTP tests would require mocking Dio
  // For now, we've tested the data structures and basic functionality
  group('Transport Error Handling', () {
    test('StorachaException is thrown with correct info', () {
      try {
        throw StorachaException(
          'Test error message',
          code: 'TestError',
          details: {'name': 'TestError', 'message': 'Test error message'},
        );
      } catch (e) {
        expect(e, isA<StorachaException>());
        expect((e as StorachaException).message, equals('Test error message'));
        expect(e.code, equals('TestError'));
      }
    });
  });
}

