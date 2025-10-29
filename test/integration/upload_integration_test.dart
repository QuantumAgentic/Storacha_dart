/// Integration tests for complete upload flow
///
/// These tests validate the entire upload pipeline from file encoding
/// to network upload, using a mock transport for deterministic testing.
import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/client/client_config.dart';
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

/// Mock transport that tracks invocations for verification
class TestableStorachaTransport implements StorachaTransport {
  TestableStorachaTransport({this.shouldSimulateExistingBlob = false});

  final bool shouldSimulateExistingBlob;

  // Track invocations
  final List<String> invocations = [];
  BlobDescriptor? lastBlobDescriptor;
  Uint8List? lastUploadedData;
  final List<Uint8List> allUploadedData = []; // Track all uploads
  UploadDescriptor? lastUploadDescriptor;

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
    invocations.add('invokeCapability');
    return <String, dynamic>{'ok': <String, dynamic>{}};
  }

  @override
  Future<BlobAllocation> invokeBlobAdd({
    required String spaceDid,
    required BlobDescriptor blob,
    required InvocationBuilder builder,
  }) async {
    invocations.add('invokeBlobAdd');
    lastBlobDescriptor = blob;

    return BlobAllocation(
      allocated: !shouldSimulateExistingBlob,
      url: shouldSimulateExistingBlob
          ? null
          : 'https://test.upload.url/blob/${blob.digest}',
      headers: shouldSimulateExistingBlob ? null : {'x-test': 'true'},
    );
  }

  @override
  Future<void> uploadBlob({
    required String url,
    required Uint8List data,
    required Map<String, String> headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    invocations.add('uploadBlob');
    lastUploadedData = data;
    allUploadedData.add(data); // Track all uploads

    // Simulate progressive upload
    final chunkSize = data.length ~/ 4;
    for (var i = 1; i <= 4; i++) {
      final sent = i == 4 ? data.length : i * chunkSize;
      onProgress?.call(sent, data.length);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Future<UploadResult> invokeUploadAdd({
    required String spaceDid,
    required CID root,
    required List<CID> shards,
    required InvocationBuilder builder,
  }) async {
    invocations.add('invokeUploadAdd');
    lastUploadDescriptor = UploadDescriptor(root: root, shards: shards);

    return UploadResult(root: root, shards: shards);
  }

  @override
  String get receiptEndpoint => 'https://test.storacha.network/receipt';

  @override
  Future<void> concludeHttpPutIfNeeded(
    String? httpPutTaskCid,
    List<Map<String, dynamic>>? httpPutTaskFacts,
  ) async {
    invocations.add('concludeHttpPutIfNeeded');
  }

  @override
  Future<void> invokeConclude({
    required InvocationBuilder builder,
  }) async {
    invocations.add('invokeConclude');
  }

  @override
  Future<Map<String, dynamic>?> pollReceipt(
    CID receiptCid, {
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    invocations.add('pollReceipt');
    return null;
  }

  @override
  Future<Map<String, dynamic>?> pollTaskReceipt(
    CID taskCid, {
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    invocations.add('pollTaskReceipt');
    return null;
  }

  @override
  void close() {
    invocations.add('close');
  }

  void reset() {
    invocations.clear();
    lastBlobDescriptor = null;
    lastUploadedData = null;
    allUploadedData.clear();
    lastUploadDescriptor = null;
  }
}

void main() {
  group('Upload Integration Tests', () {
    late StorachaClient client;
    late Signer principal;
    late TestableStorachaTransport transport;

    setUp(() async {
      principal = await Ed25519Signer.generate();
      transport = TestableStorachaTransport();
      final config = ClientConfig(principal: principal);
      client = StorachaClient(config, transport: transport);

      // Create a space for uploads
      await client.createSpace('Test Space');
    });

    tearDown(() {
      client.close();
    });

    group('Complete Upload Flow', () {
      test('uploads small text file successfully', () async {
        final file = MemoryFile(
          name: 'hello.txt',
          bytes: Uint8List.fromList(utf8.encode('Hello, Storacha!')),
        );

        final cid = await client.uploadFile(file);

        // Verify CID was returned
        expect(cid, isNotNull);
        expect(cid.version, equals(CidVersion.v1));

        // Verify all steps were called
        expect(transport.invocations, contains('invokeBlobAdd'));
        expect(transport.invocations, contains('uploadBlob'));
        expect(transport.invocations, contains('invokeUploadAdd'));

        // Verify blob descriptor was created
        expect(transport.lastBlobDescriptor, isNotNull);
        expect(transport.lastBlobDescriptor!.size, greaterThan(0));

        // Verify data was uploaded
        expect(transport.lastUploadedData, isNotNull);
        expect(transport.lastUploadedData!.isNotEmpty, isTrue);

        // Verify upload descriptor matches
        expect(transport.lastUploadDescriptor, isNotNull);
        expect(transport.lastUploadDescriptor!.root, equals(cid));
      });

      test('uploads large file with chunking', () async {
        // Create 1 MB file (will be chunked)
        final largeData = Uint8List.fromList(
          List.generate(1024 * 1024, (i) => i % 256),
        );
        final file = MemoryFile(name: 'large.bin', bytes: largeData);

        final cid = await client.uploadFile(file);

        expect(cid, isNotNull);
        expect(cid.code, equals(dagPbCode)); // Chunked files use dag-pb

        // Verify blob CAR file (first upload) was created and uploaded
        expect(transport.allUploadedData, isNotEmpty);
        expect(transport.allUploadedData.length, greaterThanOrEqualTo(2)); // blob + index
        expect(
          transport.allUploadedData.first.length,
          greaterThan(1000), // Blob CAR should be large
        );

        // Verify index CAR (second upload) is smaller
        expect(
          transport.allUploadedData[1].length,
          lessThan(1000), // Index CAR is smaller
        );
      });

      test('tracks upload progress correctly', () async {
        final file = MemoryFile(
          name: 'test.txt',
          bytes: Uint8List.fromList(utf8.encode('Test content')),
        );

        final progressUpdates = <ProgressStatus>[];
        final options = UploadFileOptions(
          onUploadProgress: (status) {
            progressUpdates.add(status);
          },
        );

        await client.uploadFile(file, options: options);

        // Verify progress updates were received
        expect(progressUpdates, isNotEmpty);

        // Verify final progress is 100%
        final finalProgress = progressUpdates.last;
        expect(finalProgress.percentage, equals(100.0));
        expect(finalProgress.loaded, equals(finalProgress.total));

        // Verify progressive updates
        for (var i = 1; i < progressUpdates.length; i++) {
          expect(
            progressUpdates[i].loaded,
            greaterThanOrEqualTo(progressUpdates[i - 1].loaded),
          );
        }
      });

      test('handles existing blob (deduplication)', () async {
        // Use transport that simulates existing blob
        final dedupTransport = TestableStorachaTransport(
          shouldSimulateExistingBlob: true,
        );
        final config = ClientConfig(principal: principal);
        final dedupClient = StorachaClient(config, transport: dedupTransport);
        await dedupClient.createSpace('Dedup Space');

        final file = MemoryFile(
          name: 'duplicate.txt',
          bytes: Uint8List.fromList(utf8.encode('Duplicate content')),
        );

        final cid = await dedupClient.uploadFile(file);

        // Verify CID was returned
        expect(cid, isNotNull);

        // Verify blob was checked
        expect(dedupTransport.invocations, contains('invokeBlobAdd'));

        // Verify upload was NOT performed (blob existed)
        expect(dedupTransport.invocations, isNot(contains('uploadBlob')));

        // Verify registration still happened
        expect(dedupTransport.invocations, contains('invokeUploadAdd'));

        dedupClient.close();
      });

      test('uploads with custom chunk size', () async {
        final file = MemoryFile(
          name: 'custom.txt',
          bytes: Uint8List.fromList(List.generate(10000, (i) => i % 256)),
        );

        const options = UploadFileOptions(
          chunkSize: 1024, // 1 KiB chunks (very small for testing)
        );

        final cid = await client.uploadFile(file, options: options);

        expect(cid, isNotNull);
        expect(cid.code, equals(dagPbCode)); // Will be chunked

        // Verify upload succeeded
        expect(transport.lastUploadDescriptor, isNotNull);
      });

      test('returns consistent CID for identical content', () async {
        final content = utf8.encode('Deterministic content');

        final file1 = MemoryFile(name: 'file1.txt', bytes: content);
        final file2 = MemoryFile(name: 'file2.txt', bytes: content);

        transport.reset();
        final cid1 = await client.uploadFile(file1);

        transport.reset();
        final cid2 = await client.uploadFile(file2);

        // Same content = same CID (content-addressable)
        expect(cid1, equals(cid2));
      });
    });

    group('Error Handling', () {
      test('throws StateError when no space selected', () async {
        // Create client without space
        final config = ClientConfig(principal: principal);
        final noSpaceClient = StorachaClient(config, transport: transport);

        final file = MemoryFile(
          name: 'test.txt',
          bytes: Uint8List.fromList(utf8.encode('test')),
        );

        expect(
          () => noSpaceClient.uploadFile(file),
          throwsStateError,
        );

        noSpaceClient.close();
      });

      test('handles empty file', () async {
        final file = MemoryFile(name: 'empty.txt', bytes: Uint8List(0));

        final cid = await client.uploadFile(file);

        expect(cid, isNotNull);
        expect(transport.lastUploadDescriptor, isNotNull);
      });
    });

    group('Space Management Integration', () {
      test('can upload to different spaces', () async {
        // Create second space
        final space2 = await client.createSpace('Second Space');

        final file = MemoryFile(
          name: 'test.txt',
          bytes: Uint8List.fromList(utf8.encode('Multi-space test')),
        );

        // Upload to second space
        client.setCurrentSpace(space2.did);
        final cid1 = await client.uploadFile(file);

        // Switch to first space
        final firstSpace = client.spaces().first;
        client.setCurrentSpace(firstSpace.did);
        transport.reset();
        final cid2 = await client.uploadFile(file);

        // Same content uploaded to different spaces
        expect(cid1, equals(cid2)); // Content-addressable
        expect(transport.invocations, contains('invokeBlobAdd'));
      });
    });

    group('Performance Characteristics', () {
      test('handles multiple sequential uploads', () async {
        final files = List.generate(
          5,
          (i) => MemoryFile(
            name: 'file$i.txt',
            bytes: Uint8List.fromList(utf8.encode('Content $i')),
          ),
        );

        final cids = <CID>[];
        for (final file in files) {
          transport.reset();
          final cid = await client.uploadFile(file);
          cids.add(cid);
        }

        // All uploads succeeded
        expect(cids, hasLength(5));

        // All CIDs are unique (different content)
        final uniqueCids = cids.toSet();
        expect(uniqueCids, hasLength(5));
      });

      test('handles large file efficiently', () async {
        // 5 MB file
        final largeFile = MemoryFile(
          name: 'large.bin',
          bytes: Uint8List.fromList(
            List.generate(5 * 1024 * 1024, (i) => i % 256),
          ),
        );

        final stopwatch = Stopwatch()..start();
        final cid = await client.uploadFile(largeFile);
        stopwatch.stop();

        expect(cid, isNotNull);
        expect(cid.code, equals(dagPbCode));

        // Should complete in reasonable time (< 5 seconds for 5MB)
        expect(stopwatch.elapsed.inSeconds, lessThan(5));

        // Verify chunking happened
        expect(transport.lastUploadDescriptor, isNotNull);
        expect(transport.lastUploadedData, isNotNull);
      });
    });

    group('Content-Addressable Verification', () {
      test('different content produces different CIDs', () async {
        final file1 = MemoryFile(
          name: 'file1.txt',
          bytes: Uint8List.fromList(utf8.encode('Content A')),
        );
        final file2 = MemoryFile(
          name: 'file2.txt',
          bytes: Uint8List.fromList(utf8.encode('Content B')),
        );

        final cid1 = await client.uploadFile(file1);
        transport.reset();
        final cid2 = await client.uploadFile(file2);

        expect(cid1, isNot(equals(cid2)));
      });

      test('CID format is valid', () async {
        final file = MemoryFile(
          name: 'test.txt',
          bytes: Uint8List.fromList(utf8.encode('Test')),
        );

        final cid = await client.uploadFile(file);

        // Verify CID structure
        expect(cid.version, equals(CidVersion.v1));
        expect(cid.toString(), startsWith('b')); // Base32 CIDv1

        // Verify CID is parseable
        final reparsed = CID.parse(cid.toString());
        expect(reparsed, equals(cid));
      });
    });
  });

  group('Real-World Scenarios', () {
    late StorachaClient client;
    late TestableStorachaTransport transport;

    setUp(() async {
      final principal = await Ed25519Signer.generate();
      transport = TestableStorachaTransport();
      final config = ClientConfig(principal: principal);
      client = StorachaClient(config, transport: transport);
      await client.createSpace('Real World Space');
    });

    tearDown(() {
      client.close();
    });

    test('simulates uploading a photo', () async {
      // Simulate a 500 KB JPEG
      final photo = MemoryFile(
        name: 'vacation.jpg',
        bytes: Uint8List.fromList(List.generate(500 * 1024, (i) => i % 256)),
      );

      var progressCallCount = 0;
      final options = UploadFileOptions(
        onUploadProgress: (status) {
          progressCallCount++;
          print(
            'Upload progress: ${status.percentage?.toStringAsFixed(1) ?? "0.0"}%',
          );
        },
      );

      final cid = await client.uploadFile(photo, options: options);

      expect(cid, isNotNull);
      expect(progressCallCount, greaterThan(0));
      print('✓ Photo uploaded: $cid');
    });

    test('simulates uploading a document', () async {
      final document = MemoryFile(
        name: 'report.pdf',
        bytes: Uint8List.fromList(
          utf8.encode('PDF content: Lorem ipsum...'),
        ),
      );

      final cid = await client.uploadFile(document);

      expect(cid, isNotNull);
      print('✓ Document uploaded: $cid');
    });

    test('simulates batch upload workflow', () async {
      final files = [
        MemoryFile(
          name: 'README.md',
          bytes: Uint8List.fromList(utf8.encode('# Project README')),
        ),
        MemoryFile(
          name: 'config.json',
          bytes: Uint8List.fromList(utf8.encode('{"key": "value"}')),
        ),
        MemoryFile(
          name: 'data.csv',
          bytes: Uint8List.fromList(utf8.encode('col1,col2\nval1,val2')),
        ),
      ];

      final uploadedCids = <String, CID>{};

      for (final file in files) {
        final cid = await client.uploadFile(file);
        uploadedCids[file.name] = cid;
        print('✓ Uploaded ${file.name}: $cid');
      }

      expect(uploadedCids, hasLength(3));
      print('✓ Batch upload complete: ${uploadedCids.length} files');
    });
  });
}

