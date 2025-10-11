import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/client/client_config.dart';
import 'package:storacha_dart/src/client/space.dart';
import 'package:storacha_dart/src/client/storacha_client.dart';
import 'package:storacha_dart/src/core/network_retry.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/transport/storacha_transport.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';
import 'package:storacha_dart/src/upload/blob.dart';
import 'package:storacha_dart/src/upload/upload_options.dart';
import 'package:test/test.dart';

/// Mock transport for testing that always succeeds
class MockStorachaTransport implements StorachaTransport {
  @override
  String get endpoint => 'https://test.storacha.network';

  @override
  RetryConfig get retryConfig => RetryPresets.fast;

  @override
  Future<Map<String, dynamic>> invokeCapability({
    required InvocationBuilder builder,
    int? expiration,
    String? nonce,
  }) async {
    // Return mock successful response
    return <String, dynamic>{'ok': <String, dynamic>{}};
  }

  @override
  Future<BlobAllocation> invokeBlobAdd({
    required String spaceDid,
    required BlobDescriptor blob,
    required InvocationBuilder builder,
  }) async {
    // Return success allocation
    return const BlobAllocation(
      allocated: true,
      url: 'https://test.upload.url/blob',
      headers: {'x-test': 'true'},
    );
  }

  @override
  Future<void> uploadBlob({
    required String url,
    required Uint8List data,
    required Map<String, String> headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    // Simulate successful upload
    onProgress?.call(data.length, data.length);
  }

  @override
  Future<UploadResult> invokeUploadAdd({
    required String spaceDid,
    required CID root,
    required List<CID> shards,
    required InvocationBuilder builder,
  }) async {
    // Return the root CID as result
    return UploadResult(root: root, shards: shards);
  }

  @override
  void close() {
    // Nothing to close in mock
  }
}

void main() {
  group('StorachaClient', () {
    late StorachaClient client;
    late Signer principal;

    setUp(() async {
      principal = await Ed25519Signer.generate();
      final config = ClientConfig(principal: principal);
      client = StorachaClient(config, transport: MockStorachaTransport());
    });

    tearDown(() {
      client.close();
    });

    group('initialization', () {
      test('creates client with principal', () async {
        expect(client.did(), isNotEmpty);
        expect(client.did(), startsWith('did:key:'));
      });

      test('has default provider', () {
        expect(client.defaultProvider(), 'did:web:storacha.network');
      });

      test('starts with no spaces', () {
        expect(client.spaces(), isEmpty);
        expect(client.currentSpace(), isNull);
      });
    });

    group('createSpace', () {
      test('creates a new space', () async {
        final space = await client.createSpace('Test Space');

        expect(space.name, 'Test Space');
        expect(space.did, isNotEmpty);
        expect(space.did, startsWith('did:key:'));
        expect(space.createdAt, isNotNull);
      });

      test('adds space to spaces list', () async {
        final space = await client.createSpace('Test Space');

        expect(client.spaces(), contains(space));
      });

      test('sets first space as current', () async {
        final space = await client.createSpace('First Space');

        expect(client.currentSpace(), equals(space));
      });

      test('creates multiple spaces', () async {
        final space1 = await client.createSpace('Space 1');
        final space2 = await client.createSpace('Space 2');
        final space3 = await client.createSpace('Space 3');

        expect(client.spaces().length, 3);
        expect(client.spaces(), containsAll([space1, space2, space3]));
      });

      test('creates space with custom signer', () async {
        final customSigner = await Ed25519Signer.generate();
        final space = await client.createSpace(
          'Custom Space',
          spaceSigner: customSigner,
        );

        expect(space.did, customSigner.did().did());
      });

      test('each space has unique DID', () async {
        final space1 = await client.createSpace('Space 1');
        final space2 = await client.createSpace('Space 2');

        expect(space1.did, isNot(equals(space2.did)));
      });
    });

    group('setCurrentSpace', () {
      test('sets current space', () async {
        final space1 = await client.createSpace('Space 1');
        final space2 = await client.createSpace('Space 2');

        client.setCurrentSpace(space2.did);
        expect(client.currentSpace(), equals(space2));

        client.setCurrentSpace(space1.did);
        expect(client.currentSpace(), equals(space1));
      });

      test('throws on invalid space DID', () async {
        await client.createSpace('Test Space');

        expect(
          () => client.setCurrentSpace('did:key:zinvalid'),
          throwsArgumentError,
        );
      });
    });

    group('addSpace', () {
      test('adds existing space', () async {
        final signer = await Ed25519Signer.generate();
        final space = Space(
          did: signer.did().did(),
          name: 'External Space',
          signer: signer,
        );

        client.addSpace(space);

        expect(client.spaces(), contains(space));
      });

      test('throws on duplicate space', () async {
        final signer = await Ed25519Signer.generate();
        final space = Space(
          did: signer.did().did(),
          name: 'Test Space',
          signer: signer,
        );

        client.addSpace(space);

        expect(() => client.addSpace(space), throwsArgumentError);
      });

      test('sets first added space as current', () async {
        final signer = await Ed25519Signer.generate();
        final space = Space(
          did: signer.did().did(),
          name: 'First Space',
          signer: signer,
        );

        client.addSpace(space);

        expect(client.currentSpace(), equals(space));
      });
    });

    group('removeSpace', () {
      test('removes space', () async {
        final space = await client.createSpace('Test Space');

        final removed = client.removeSpace(space.did);

        expect(removed, isTrue);
        expect(client.spaces(), isNot(contains(space)));
      });

      test('returns false for non-existent space', () {
        final removed = client.removeSpace('did:key:zinvalid');

        expect(removed, isFalse);
      });

      test('selects another space when current is removed', () async {
        final space1 = await client.createSpace('Space 1');
        final space2 = await client.createSpace('Space 2');

        // Space 1 is current
        expect(client.currentSpace(), equals(space1));

        // Remove current space
        client.removeSpace(space1.did);

        // Space 2 should become current
        expect(client.currentSpace(), equals(space2));
      });

      test('sets currentSpace to null when last space is removed', () async {
        final space = await client.createSpace('Only Space');

        client.removeSpace(space.did);

        expect(client.currentSpace(), isNull);
        expect(client.spaces(), isEmpty);
      });
    });

    group('integration', () {
      test('full space lifecycle', () async {
        // Create first space
        final space1 = await client.createSpace('Personal');
        expect(client.currentSpace(), equals(space1));
        expect(client.spaces().length, 1);

        // Create second space
        final space2 = await client.createSpace('Work');
        expect(client.currentSpace(), equals(space1)); // Still first
        expect(client.spaces().length, 2);

        // Switch to second space
        client.setCurrentSpace(space2.did);
        expect(client.currentSpace(), equals(space2));

        // Remove first space
        client.removeSpace(space1.did);
        expect(client.currentSpace(), equals(space2)); // Still second
        expect(client.spaces().length, 1);

        // Remove last space
        client.removeSpace(space2.did);
        expect(client.currentSpace(), isNull);
        expect(client.spaces(), isEmpty);
      });

      test('client DID matches principal', () async {
        final clientDid = client.did();
        final principalDid = principal.did().did();

        expect(clientDid, equals(principalDid));
      });
    });
  });

  group('ClientConfig', () {
    test('creates config with defaults', () async {
      final signer = await Ed25519Signer.generate();
      final config = ClientConfig(principal: signer);

      expect(config.endpoints, equals(StorachaEndpoints.production));
      expect(config.defaultProvider, 'did:web:storacha.network');
    });

    test('creates config with custom endpoints', () async {
      final signer = await Ed25519Signer.generate();
      final config = ClientConfig(
        principal: signer,
        endpoints: StorachaEndpoints.staging,
      );

      expect(
        config.endpoints.serviceUrl,
        'https://staging.up.storacha.network',
      );
    });
  });

  group('Space', () {
    test('creates space', () async {
      final signer = await Ed25519Signer.generate();
      final space = Space(
        did: signer.did().did(),
        name: 'Test Space',
        signer: signer,
      );

      expect(space.name, 'Test Space');
      expect(space.did, isNotEmpty);
    });

    test('converts to JSON', () async {
      final signer = await Ed25519Signer.generate();
      final space = Space(
        did: signer.did().did(),
        name: 'Test Space',
        signer: signer,
        createdAt: DateTime(2024),
      );

      final json = space.toJson();

      expect(json['did'], space.did);
      expect(json['name'], 'Test Space');
      expect(json['createdAt'], isNotNull);
    });

    test('equality works correctly', () async {
      final signer = await Ed25519Signer.generate();
      final space1 = Space(
        did: signer.did().did(),
        name: 'Test Space',
        signer: signer,
      );
      final space2 = Space(
        did: signer.did().did(),
        name: 'Test Space',
        signer: signer,
      );

      expect(space1, equals(space2));
      expect(space1.hashCode, equals(space2.hashCode));
    });

    test('toString provides useful info', () async {
      final signer = await Ed25519Signer.generate();
      final space = Space(
        did: signer.did().did(),
        name: 'Test Space',
        signer: signer,
      );

      final str = space.toString();

      expect(str, contains('Test Space'));
      expect(str, contains(space.did));
    });
  });

  group('Upload', () {
    late StorachaClient client;
    late Signer principal;

    setUp(() async {
      principal = await Ed25519Signer.generate();
      final config = ClientConfig(principal: principal);
      client = StorachaClient(config, transport: MockStorachaTransport());
    });

    tearDown(() {
      client.close();
    });

    test('uploadFile throws StateError when no space selected', () {
      final file = MemoryFile(
        name: 'test.txt',
        bytes: Uint8List.fromList(utf8.encode('test')),
      );

      expect(
        () => client.uploadFile(file),
        throwsStateError,
      );
    });

    test('uploadFile returns CID for small file', () async {
      await client.createSpace('Test Space');

      final file = MemoryFile(
        name: 'test.txt',
        bytes: Uint8List.fromList(utf8.encode('Hello, World!')),
      );

      final cid = await client.uploadFile(file);

      expect(cid, isNotNull);
      expect(cid.version, equals(CidVersion.v1));
      expect(cid.toString(), isNotEmpty);
    });

    test('uploadFile returns CID for chunked file', () async {
      await client.createSpace('Test Space');

      // Create a file larger than default chunk size (256 KiB)
      final largeData = Uint8List.fromList(
        List.generate(300 * 1024, (i) => i % 256),
      );
      final file = MemoryFile(
        name: 'large.bin',
        bytes: largeData,
      );

      final cid = await client.uploadFile(file);

      expect(cid, isNotNull);
      expect(cid.version, equals(CidVersion.v1));
      // Chunked files use dag-pb codec
      expect(cid.code, equals(dagPbCode));
    });

    test('uploadFile accepts custom chunk size', () async {
      await client.createSpace('Test Space');

      final file = MemoryFile(
        name: 'test.txt',
        bytes: Uint8List.fromList(List.generate(1000, (i) => i % 256)),
      );

      const options = UploadFileOptions(
        chunkSize: 256, // Small chunks for testing
      );

      final cid = await client.uploadFile(file, options: options);

      expect(cid, isNotNull);
      // With small chunks, file will be chunked
      expect(cid.code, equals(dagPbCode));
    });

    test('uploadFile calls progress callback', () async {
      await client.createSpace('Test Space');

      final file = MemoryFile(
        name: 'test.txt',
        bytes: Uint8List.fromList(utf8.encode('Hello!')),
      );

      ProgressStatus? lastStatus;
      final options = UploadFileOptions(
        onUploadProgress: (status) {
          lastStatus = status;
        },
      );

      await client.uploadFile(file, options: options);

      expect(lastStatus, isNotNull);
      expect(lastStatus!.percentage, equals(100.0));
    });

    test('uploadFile returns consistent CID for same content', () async {
      await client.createSpace('Test Space');

      final data = utf8.encode('consistent content');
      final file1 = MemoryFile(name: 'file1.txt', bytes: data);
      final file2 = MemoryFile(name: 'file2.txt', bytes: data);

      final cid1 = await client.uploadFile(file1);
      final cid2 = await client.uploadFile(file2);

      // Same content should produce same CID (content-addressable)
      expect(cid1, equals(cid2));
    });

    test('uploadDirectory throws StateError when no space selected', () {
      final files = [
        MemoryFile(
          name: 'file1.txt',
          bytes: Uint8List.fromList(utf8.encode('content1')),
        ),
      ];

      expect(
        () => client.uploadDirectory(files),
        throwsStateError,
      );
    });

    test('uploadDirectory throws ArgumentError for empty list', () async {
      await client.createSpace('Test Space');

      expect(
        () => client.uploadDirectory([]),
        throwsArgumentError,
      );
    });

    test(
      'uploadDirectory throws UnimplementedError with valid input',
      () async {
        await client.createSpace('Test Space');

        final files = [
          MemoryFile(
            name: 'README.md',
            bytes: Uint8List.fromList(utf8.encode('# Project')),
          ),
          MemoryFile(
            name: 'src/main.dart',
            bytes: Uint8List.fromList(utf8.encode('void main() {}')),
          ),
        ];

        expect(
          () => client.uploadDirectory(files),
          throwsUnimplementedError,
        );
      },
    );

    test('uploadDirectory accepts options', () async {
      await client.createSpace('Test Space');

      final files = [
        MemoryFile(
          name: 'file.txt',
          bytes: Uint8List.fromList(utf8.encode('content')),
        ),
      ];

      const options = UploadDirectoryOptions(
        customOrder: true,
        chunkSize: 128 * 1024,
      );

      expect(
        () => client.uploadDirectory(files, options: options),
        throwsUnimplementedError,
      );
    });
  });
}
