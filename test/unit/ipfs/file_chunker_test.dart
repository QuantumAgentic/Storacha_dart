import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/unixfs/file_chunker.dart';
import 'package:storacha_dart/src/upload/blob.dart';
import 'package:test/test.dart';

void main() {
  group('FileChunker', () {
    test('chunks small file (< chunk size)', () async {
      const chunkSize = 1024;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create a 500 byte file
      final data = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(1));
      expect(chunks[0].length, equals(500));
      expect(chunks[0], equals(data));
    });

    test('chunks file exactly at chunk size', () async {
      const chunkSize = 1024;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create exactly 1024 bytes
      final data = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(1));
      expect(chunks[0].length, equals(1024));
    });

    test('chunks file into multiple equal chunks', () async {
      const chunkSize = 256;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create 1024 bytes (4 chunks of 256)
      final data = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(4));
      for (var i = 0; i < 4; i++) {
        expect(chunks[i].length, equals(256));
        // Verify data integrity
        expect(chunks[i], equals(data.sublist(i * 256, (i + 1) * 256)));
      }
    });

    test('chunks file with remainder', () async {
      const chunkSize = 256;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create 1000 bytes (3 full chunks + 232 bytes)
      final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(4));
      expect(chunks[0].length, equals(256));
      expect(chunks[1].length, equals(256));
      expect(chunks[2].length, equals(256));
      expect(chunks[3].length, equals(232)); // Remainder

      // Verify data integrity
      final reconstructed = BytesBuilder();
      for (final chunk in chunks) {
        reconstructed.add(chunk);
      }
      expect(reconstructed.toBytes(), equals(data));
    });

    test('chunks large file', () async {
      const chunkSize = 256 * 1024; // 256 KiB
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create 1 MB file (4 chunks)
      final megabyte = 1024 * 1024;
      final data = Uint8List.fromList(List.generate(megabyte, (i) => i % 256));
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(4));
      for (var i = 0; i < 4; i++) {
        expect(chunks[i].length, equals(chunkSize));
      }
    });

    test('handles empty file', () async {
      final chunker = FileChunker();
      final blob = MemoryBlob(bytes: Uint8List(0));

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks, isEmpty);
    });

    test('uses default chunk size', () async {
      final chunker = FileChunker();
      expect(chunker.chunkSize, equals(256 * 1024)); // 256 KiB
    });

    test('allows custom chunk size', () async {
      const customSize = 512 * 1024; // 512 KiB
      final chunker = FileChunker(chunkSize: customSize);

      expect(chunker.chunkSize, equals(customSize));
    });

    test('estimates chunk count correctly', () {
      const chunkSize = 256;
      final chunker = FileChunker(chunkSize: chunkSize);

      expect(chunker.estimateChunkCount(0), equals(0));
      expect(chunker.estimateChunkCount(1), equals(1));
      expect(chunker.estimateChunkCount(256), equals(1));
      expect(chunker.estimateChunkCount(257), equals(2));
      expect(chunker.estimateChunkCount(512), equals(2));
      expect(chunker.estimateChunkCount(1000), equals(4)); // 256*3 + 232
    });

    test('maintains data integrity across chunk boundaries', () async {
      const chunkSize = 100;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create data with recognizable pattern
      final data = Uint8List.fromList([
        for (var i = 0; i < 250; i++) i % 256,
      ]);
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      // Reconstruct and verify
      final reconstructed = BytesBuilder();
      for (final chunk in chunks) {
        reconstructed.add(chunk);
      }

      expect(reconstructed.toBytes(), equals(data));
    });

    test('chunks data arriving in small pieces', () async {
      const chunkSize = 1024;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create a stream that yields data in small pieces
      Stream<Uint8List> smallPieceStream() async* {
        for (var i = 0; i < 10; i++) {
          // Yield 200 bytes at a time (total 2000 bytes)
          yield Uint8List.fromList(List.generate(200, (j) => (i * 200 + j)));
        }
      }

      final blob = _StreamBlob(smallPieceStream, 2000);
      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(2)); // 1024 + 976
      expect(chunks[0].length, equals(1024));
      expect(chunks[1].length, equals(976));
    });

    test('chunks data arriving in large pieces', () async {
      const chunkSize = 256;
      final chunker = FileChunker(chunkSize: chunkSize);

      // Create a stream that yields data in large pieces
      Stream<Uint8List> largePieceStream() async* {
        // Yield 1000 bytes at once
        yield Uint8List.fromList(List.generate(1000, (i) => i % 256));
      }

      final blob = _StreamBlob(largePieceStream, 1000);
      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(4)); // 256 * 3 + 232
      expect(chunks[0].length, equals(256));
      expect(chunks[1].length, equals(256));
      expect(chunks[2].length, equals(256));
      expect(chunks[3].length, equals(232));
    });
  });

  group('Integration: FileChunker with real-world scenarios', () {
    test('chunks a 10 MB file with 256 KiB chunks', () async {
      const chunkSize = 256 * 1024;
      final chunker = FileChunker(chunkSize: chunkSize);

      final fileSize = 10 * 1024 * 1024; // 10 MB
      final expectedChunks = (fileSize / chunkSize).ceil();

      // Simulate large file with pattern
      Stream<Uint8List> largeFileStream() async* {
        const pieceSize = 1024 * 1024; // 1 MB pieces
        for (var i = 0; i < 10; i++) {
          yield Uint8List.fromList(
            List.generate(pieceSize, (j) => (i + j) % 256),
          );
        }
      }

      final blob = _StreamBlob(largeFileStream, fileSize);
      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(expectedChunks));

      // Verify all chunks except last are full size
      for (var i = 0; i < chunks.length - 1; i++) {
        expect(chunks[i].length, equals(chunkSize));
      }

      // Verify total size
      final totalSize = chunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );
      expect(totalSize, equals(fileSize));
    });

    test('handles very small chunk size', () async {
      const chunkSize = 10; // Tiny chunks
      final chunker = FileChunker(chunkSize: chunkSize);

      final data = Uint8List.fromList(List.generate(100, (i) => i));
      final blob = MemoryBlob(bytes: data);

      final chunks = await chunker.chunk(blob).toList();

      expect(chunks.length, equals(10));
      for (final chunk in chunks) {
        expect(chunk.length, equals(10));
      }
    });
  });
}

/// Helper class for testing with custom streams.
class _StreamBlob implements BlobLike {
  _StreamBlob(this._stream, this._size);

  final Stream<Uint8List> Function() _stream;
  final int _size;

  @override
  Stream<Uint8List> stream() => _stream();

  @override
  int get size => _size;
}

