import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:test/test.dart';

void main() {
  group('BlobDescriptor', () {
    test('creates descriptor with digest and size', () {
      final digest = Uint8List.fromList([1, 2, 3, 4]);
      const size = 1024;

      final descriptor = BlobDescriptor(digest: digest, size: size);

      expect(descriptor.digest, equals(digest));
      expect(descriptor.size, equals(size));
    });

    test('converts to JSON', () {
      final digest = Uint8List.fromList([1, 2, 3, 4]);
      const size = 1024;
      final descriptor = BlobDescriptor(digest: digest, size: size);

      final json = descriptor.toJson();

      expect(json['digest'], equals(digest));
      expect(json['size'], equals(size));
    });

    test('equality works correctly', () {
      final digest1 = Uint8List.fromList([1, 2, 3]);
      final digest2 = Uint8List.fromList([1, 2, 3]);
      final digest3 = Uint8List.fromList([1, 2, 4]);

      final desc1 = BlobDescriptor(digest: digest1, size: 100);
      final desc2 = BlobDescriptor(digest: digest2, size: 100);
      final desc3 = BlobDescriptor(digest: digest3, size: 100);

      expect(desc1, equals(desc2));
      expect(desc1, isNot(equals(desc3)));
    });

    test('toString provides useful info', () {
      final digest = Uint8List.fromList([1, 2, 3, 4]);
      final descriptor = BlobDescriptor(digest: digest, size: 1024);

      final str = descriptor.toString();

      expect(str, contains('BlobDescriptor'));
      expect(str, contains('4 bytes'));
      expect(str, contains('1024'));
    });
  });

  group('BlobAllocation', () {
    test('creates allocation with URL', () {
      const allocation = BlobAllocation(
        allocated: true,
        url: 'https://example.com/upload',
        headers: {'Authorization': 'Bearer token'},
      );

      expect(allocation.allocated, isTrue);
      expect(allocation.url, equals('https://example.com/upload'));
      expect(allocation.headers, isNotNull);
    });

    test('creates allocation for existing blob', () {
      const allocation = BlobAllocation(allocated: false);

      expect(allocation.allocated, isFalse);
      expect(allocation.url, isNull);
      expect(allocation.headers, isNull);
    });

    test('parses from JSON with site', () {
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

    test('parses from JSON without site', () {
      final json = {'allocated': false};

      final allocation = BlobAllocation.fromJson(json);

      expect(allocation.allocated, isFalse);
      expect(allocation.url, isNull);
    });
  });

  group('UploadDescriptor', () {
    test('creates descriptor with root CID', () {
      final cid = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final descriptor = UploadDescriptor(root: cid);

      expect(descriptor.root, equals(cid));
      expect(descriptor.shards, isNull);
    });

    test('creates descriptor with shards', () {
      final root = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final shard1 = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([2])));
      final shard2 = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([3])));

      final descriptor = UploadDescriptor(
        root: root,
        shards: [shard1, shard2],
      );

      expect(descriptor.root, equals(root));
      expect(descriptor.shards, hasLength(2));
    });

    test('converts to JSON', () {
      final root = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final shard = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([2])));
      final descriptor = UploadDescriptor(root: root, shards: [shard]);

      final json = descriptor.toJson();

      expect(json['root'], isNotNull);
      expect(json['shards'], isNotNull);
      expect(json['shards'], hasLength(1));
    });
  });

  group('UploadResult', () {
    test('creates result with root', () {
      final cid = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final result = UploadResult(root: cid);

      expect(result.root, equals(cid));
      expect(result.shards, isNull);
    });

    test('parses from JSON', () {
      final cid = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final json = {
        'root': cid.toJson(),
        'shards': [cid.toJson()],
      };

      final result = UploadResult.fromJson(json);

      expect(result.root, equals(cid));
      expect(result.shards, hasLength(1));
    });
  });
}

