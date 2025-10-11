import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';
import 'package:storacha_dart/src/ipfs/unixfs/unixfs_encoder.dart';
import 'package:storacha_dart/src/ipfs/unixfs/unixfs_types.dart';
import 'package:storacha_dart/src/upload/blob.dart';
import 'package:test/test.dart';

void main() {
  group('UnixFSEncoder', () {
    test('encodes small file as single raw block', () async {
      final encoder = UnixFSEncoder();

      // Create a 100-byte file (< 256 KiB default chunk size)
      final data = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // Should have exactly 1 block
      expect(result.blocks.length, equals(1));

      // Block should be raw codec
      expect(result.rootCID.version, equals(CidVersion.v1));
      expect(result.rootCID.code, equals(rawCode));

      // Block data should match input
      expect(result.blocks[0].bytes, equals(data));
      expect(result.blocks[0].cid, equals(result.rootCID));
    });

    test('encodes empty file', () async {
      final encoder = UnixFSEncoder();
      final file = MemoryBlob(bytes: Uint8List(0));

      final result = await encoder.encodeFile(file);

      expect(result.blocks.length, equals(1));
      expect(result.blocks[0].bytes, isEmpty);
    });

    test('encodes file exactly at chunk size', () async {
      const chunkSize = 1024;
      final encoder = UnixFSEncoder(
        options: UnixFSEncodeOptions(chunkSize: chunkSize),
      );

      // Exactly 1024 bytes
      final data = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // Should be single block (not chunked)
      expect(result.blocks.length, equals(1));
      expect(result.rootCID.code, equals(rawCode));
    });

    test('encodes chunked file with root node', () async {
      const chunkSize = 256;
      final encoder = UnixFSEncoder(
        options: UnixFSEncodeOptions(chunkSize: chunkSize),
      );

      // 1000 bytes = 3 full chunks (256 each) + 1 partial (232 bytes)
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // Should have 4 leaf blocks + 1 root block = 5 total
      expect(result.blocks.length, equals(5));

      // Root should be dag-pb
      expect(result.rootCID.code, equals(dagPbCode));

      // First 4 blocks should be leaves (raw codec)
      for (var i = 0; i < 4; i++) {
        expect(result.blocks[i].cid.code, equals(rawCode));
      }

      // Last block should be root (dag-pb)
      expect(result.blocks[4].cid, equals(result.rootCID));
      expect(result.blocks[4].cid.code, equals(dagPbCode));
    });

    test('encodes large file', () async {
      const chunkSize = 256 * 1024; // 256 KiB
      final encoder = UnixFSEncoder(
        options: UnixFSEncodeOptions(chunkSize: chunkSize),
      );

      // 1 MB file = 4 chunks
      final megabyte = 1024 * 1024;
      final data = Uint8List.fromList(List.generate(megabyte, (i) => i % 256));
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // 4 leaf blocks + 1 root = 5 total
      expect(result.blocks.length, equals(5));
      expect(result.rootCID.code, equals(dagPbCode));

      // Verify leaf sizes
      for (var i = 0; i < 4; i++) {
        expect(result.blocks[i].bytes.length, equals(chunkSize));
      }
    });

    test('maintains data integrity for chunked files', () async {
      const chunkSize = 100;
      final encoder = UnixFSEncoder(
        options: UnixFSEncodeOptions(chunkSize: chunkSize),
      );

      // Create recognizable pattern
      final data = Uint8List.fromList([
        for (var i = 0; i < 350; i++) i % 256,
      ]);
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // Reconstruct data from leaf blocks (all but last which is root)
      final reconstructed = BytesBuilder();
      for (var i = 0; i < result.blocks.length - 1; i++) {
        reconstructed.add(result.blocks[i].bytes);
      }

      expect(reconstructed.toBytes(), equals(data));
    });

    test('uses custom chunk size', () async {
      const customChunkSize = 512;
      final encoder = UnixFSEncoder(
        options: UnixFSEncodeOptions(chunkSize: customChunkSize),
      );

      // 1000 bytes with 512-byte chunks = 2 chunks (512 + 488)
      final data = Uint8List.fromList(List.generate(1000, (i) => i));
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // 2 leaf blocks + 1 root = 3 total
      expect(result.blocks.length, equals(3));

      // Verify leaf sizes
      expect(result.blocks[0].bytes.length, equals(512));
      expect(result.blocks[1].bytes.length, equals(488));
    });

    test('generates consistent CIDs', () async {
      final encoder = UnixFSEncoder();

      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final file1 = MemoryBlob(bytes: data);
      final file2 = MemoryBlob(bytes: data);

      final result1 = await encoder.encodeFile(file1);
      final result2 = await encoder.encodeFile(file2);

      // Same data should produce same CID
      expect(result1.rootCID, equals(result2.rootCID));
    });

    test('generates different CIDs for different data', () async {
      final encoder = UnixFSEncoder();

      final file1 = MemoryBlob(bytes: Uint8List.fromList([1, 2, 3]));
      final file2 = MemoryBlob(bytes: Uint8List.fromList([4, 5, 6]));

      final result1 = await encoder.encodeFile(file1);
      final result2 = await encoder.encodeFile(file2);

      expect(result1.rootCID, isNot(equals(result2.rootCID)));
    });
  });

  group('Integration: UnixFS encoding pipeline', () {
    test('encodes and verifies a real file', () async {
      final encoder = UnixFSEncoder();

      // Create a "Hello, World!" file
      final content = 'Hello, World!';
      final data = Uint8List.fromList(content.codeUnits);
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // Single block
      expect(result.blocks.length, equals(1));
      expect(result.blocks[0].bytes, equals(data));

      // CID should be valid
      expect(result.rootCID.version, equals(CidVersion.v1));
      expect(result.rootCID.toString(), startsWith('baf')); // CIDv1 base32
    });

    test('encodes a chunked file and verifies structure', () async {
      const chunkSize = 10;
      final encoder = UnixFSEncoder(
        options: UnixFSEncodeOptions(chunkSize: chunkSize),
      );

      // 35 bytes = 4 chunks (10, 10, 10, 5)
      final data = Uint8List.fromList(List.generate(35, (i) => i));
      final file = MemoryBlob(bytes: data);

      final result = await encoder.encodeFile(file);

      // 4 leaves + 1 root = 5 blocks
      expect(result.blocks.length, equals(5));

      // Verify leaf blocks are in order
      expect(result.blocks[0].bytes.length, equals(10));
      expect(result.blocks[1].bytes.length, equals(10));
      expect(result.blocks[2].bytes.length, equals(10));
      expect(result.blocks[3].bytes.length, equals(5));

      // Root is last
      expect(result.blocks[4].cid, equals(result.rootCID));

      // Root uses dag-pb
      expect(result.rootCID.code, equals(dagPbCode));

      // CID is valid multibase string
      final cidString = result.rootCID.toString();
      expect(cidString, isNotEmpty);
      expect(() => CID.parse(cidString), returnsNormally);
    });

    test('handles various file sizes correctly', () async {
      final encoder = UnixFSEncoder(
        options: const UnixFSEncodeOptions(chunkSize: 1024),
      );

      final testCases = [
        (size: 0, expectedBlocks: 1),
        (size: 100, expectedBlocks: 1),
        (size: 1024, expectedBlocks: 1),
        (size: 1025, expectedBlocks: 3), // 2 leaves + 1 root
        (size: 2048, expectedBlocks: 3), // 2 leaves + 1 root
        (size: 3000, expectedBlocks: 4), // 3 leaves + 1 root
      ];

      for (final testCase in testCases) {
        final data = Uint8List.fromList(
          List.generate(testCase.size, (i) => i % 256),
        );
        final file = MemoryBlob(bytes: data);

        final result = await encoder.encodeFile(file);

        expect(
          result.blocks.length,
          equals(testCase.expectedBlocks),
          reason: 'File size ${testCase.size}',
        );
      }
    });
  });
}

