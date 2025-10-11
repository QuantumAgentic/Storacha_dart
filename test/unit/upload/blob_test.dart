import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:storacha_dart/src/upload/blob.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryBlob', () {
    test('creates blob with bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final blob = MemoryBlob(bytes: bytes);

      expect(blob.bytes, equals(bytes));
      expect(blob.size, equals(5));
    });

    test('streams bytes', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final blob = MemoryBlob(bytes: bytes);

      final chunks = <Uint8List>[];
      await for (final chunk in blob.stream()) {
        chunks.add(chunk);
      }

      expect(chunks.length, equals(1));
      expect(chunks[0], equals(bytes));
    });

    test('equality works correctly', () {
      final bytes1 = Uint8List.fromList([1, 2, 3]);
      final bytes2 = Uint8List.fromList([1, 2, 3]);
      final bytes3 = Uint8List.fromList([4, 5, 6]);

      final blob1 = MemoryBlob(bytes: bytes1);
      final blob2 = MemoryBlob(bytes: bytes2);
      final blob3 = MemoryBlob(bytes: bytes3);

      expect(blob1, equals(blob2));
      expect(blob1, isNot(equals(blob3)));
    });

    test('toString provides useful info', () {
      final blob = MemoryBlob(bytes: Uint8List(100));

      final str = blob.toString();

      expect(str, contains('MemoryBlob'));
      expect(str, contains('100'));
      expect(str, contains('bytes'));
    });

    test('handles empty blob', () {
      final blob = MemoryBlob(bytes: Uint8List(0));

      expect(blob.size, equals(0));
    });

    test('handles large blob size', () {
      final largeBlob = MemoryBlob(bytes: Uint8List(1024 * 1024)); // 1MB

      expect(largeBlob.size, equals(1024 * 1024));
    });
  });

  group('MemoryFile', () {
    test('creates file with name and bytes', () {
      final bytes = Uint8List.fromList(utf8.encode('Hello, World!'));
      final file = MemoryFile(name: 'hello.txt', bytes: bytes);

      expect(file.name, equals('hello.txt'));
      expect(file.bytes, equals(bytes));
      expect(file.size, equals(bytes.length));
    });

    test('streams bytes', () async {
      final bytes = Uint8List.fromList(utf8.encode('Test data'));
      final file = MemoryFile(name: 'test.txt', bytes: bytes);

      final chunks = <Uint8List>[];
      await for (final chunk in file.stream()) {
        chunks.add(chunk);
      }

      expect(chunks.length, equals(1));
      expect(chunks[0], equals(bytes));
    });

    test('preserves file path information', () {
      final file = MemoryFile(
        name: 'src/main.dart',
        bytes: Uint8List(0),
      );

      expect(file.name, equals('src/main.dart'));
    });

    test('equality works correctly', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final file1 = MemoryFile(name: 'file.txt', bytes: bytes);
      final file2 = MemoryFile(name: 'file.txt', bytes: bytes);
      final file3 = MemoryFile(name: 'other.txt', bytes: bytes);

      expect(file1, equals(file2));
      expect(file1, isNot(equals(file3)));
    });

    test('toString provides useful info', () {
      final file = MemoryFile(
        name: 'document.pdf',
        bytes: Uint8List(2048),
      );

      final str = file.toString();

      expect(str, contains('MemoryFile'));
      expect(str, contains('document.pdf'));
      expect(str, contains('2048'));
      expect(str, contains('bytes'));
    });

    test('handles various file types', () {
      final files = [
        MemoryFile(name: 'image.jpg', bytes: Uint8List(100)),
        MemoryFile(name: 'video.mp4', bytes: Uint8List(200)),
        MemoryFile(name: 'data.json', bytes: Uint8List(50)),
      ];

      expect(files[0].name, equals('image.jpg'));
      expect(files[1].name, equals('video.mp4'));
      expect(files[2].name, equals('data.json'));
    });
  });

  group('Integration', () {
    test('FileLike implements BlobLike', () {
      final file = MemoryFile(name: 'test.txt', bytes: Uint8List(10));
      final BlobLike blob = file;

      expect(blob.size, equals(10));
    });

    test('real-world file simulation', () async {
      // Simulate a JSON config file
      final config = '{"version": "1.0", "name": "My App"}';
      final configBytes = Uint8List.fromList(utf8.encode(config));
      final configFile = MemoryFile(
        name: 'config.json',
        bytes: configBytes,
      );

      expect(configFile.name, equals('config.json'));
      expect(configFile.size, equals(configBytes.length));

      // Read the stream
      final chunks = <Uint8List>[];
      await for (final chunk in configFile.stream()) {
        chunks.add(chunk);
      }

      // Verify we can reconstruct the original
      final reconstructed = utf8.decode(chunks[0]);
      expect(reconstructed, equals(config));
    });

    test('directory structure simulation', () {
      final files = [
        MemoryFile(
          name: 'README.md',
          bytes: Uint8List.fromList(utf8.encode('# My Project')),
        ),
        MemoryFile(
          name: 'src/main.dart',
          bytes: Uint8List.fromList(utf8.encode('void main() {}')),
        ),
        MemoryFile(
          name: 'src/utils/helper.dart',
          bytes: Uint8List.fromList(utf8.encode('// Helper functions')),
        ),
      ];

      expect(files.length, equals(3));
      expect(files[0].name, equals('README.md'));
      expect(files[1].name, contains('src/'));
      expect(files[2].name, contains('utils/'));
    });
  });

  group('FileBlob', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storacha_test_');
      testFile = File('${tempDir.path}/test.bin');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates blob from file', () async {
      await testFile.writeAsBytes([1, 2, 3, 4, 5]);
      final blob = FileBlob(testFile);

      expect(blob.file, equals(testFile));
      expect(blob.size, equals(5));
      expect(blob.chunkSize, equals(256 * 1024)); // Default
    });

    test('streams file contents', () async {
      final content = List.generate(1000, (i) => i % 256);
      await testFile.writeAsBytes(content);

      final blob = FileBlob(testFile);
      final chunks = <Uint8List>[];

      await for (final chunk in blob.stream()) {
        chunks.add(chunk);
      }

      // Should have 1 chunk for small file
      expect(chunks.length, equals(1));

      // Reconstruct original content
      final reconstructed = <int>[];
      for (final chunk in chunks) {
        reconstructed.addAll(chunk);
      }
      expect(reconstructed, equals(content));
    });

    test('streams large file in chunks', () async {
      // Create 1 MB file
      final content = List.generate(1024 * 1024, (i) => i % 256);
      await testFile.writeAsBytes(content);

      final blob = FileBlob(testFile, chunkSize: 256 * 1024);
      final chunks = <Uint8List>[];

      await for (final chunk in blob.stream()) {
        chunks.add(chunk);
      }

      // Should have 4 chunks (1 MB / 256 KiB = 4)
      expect(chunks.length, equals(4));

      // Each chunk should be 256 KiB
      for (final chunk in chunks) {
        expect(chunk.length, equals(256 * 1024));
      }

      // Reconstruct and verify
      final reconstructed = <int>[];
      for (final chunk in chunks) {
        reconstructed.addAll(chunk);
      }
      expect(reconstructed, equals(content));
    });

    test('handles custom chunk size', () async {
      final content = List.generate(100, (i) => i);
      await testFile.writeAsBytes(content);

      final blob = FileBlob(testFile, chunkSize: 30);
      final chunks = <Uint8List>[];

      await for (final chunk in blob.stream()) {
        chunks.add(chunk);
      }

      // Should have 4 chunks: 30 + 30 + 30 + 10
      expect(chunks.length, equals(4));
      expect(chunks[0].length, equals(30));
      expect(chunks[1].length, equals(30));
      expect(chunks[2].length, equals(30));
      expect(chunks[3].length, equals(10));
    });

    test('handles empty file', () async {
      await testFile.writeAsBytes([]);
      final blob = FileBlob(testFile);

      final chunks = <Uint8List>[];
      await for (final chunk in blob.stream()) {
        chunks.add(chunk);
      }

      expect(chunks, isEmpty);
      expect(blob.size, equals(0));
    });

    test('equality works correctly', () async {
      await testFile.writeAsBytes([1, 2, 3]);
      final blob1 = FileBlob(testFile);
      final blob2 = FileBlob(testFile);
      final blob3 = FileBlob(testFile, chunkSize: 512 * 1024);

      expect(blob1, equals(blob2));
      expect(blob1, isNot(equals(blob3))); // Different chunk size
    });

    test('toString provides useful info', () async {
      await testFile.writeAsBytes(List.generate(1024, (i) => i));
      final blob = FileBlob(testFile);

      final str = blob.toString();

      expect(str, contains('FileBlob'));
      expect(str, contains(testFile.path));
      expect(str, contains('1024'));
      expect(str, contains('262144')); // Default chunk size
    });
  });

  group('FileLikeFromFile', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storacha_test_');
      testFile = File('${tempDir.path}/document.pdf');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates file-like from file', () async {
      await testFile.writeAsBytes([1, 2, 3]);
      final fileLike = FileLikeFromFile(testFile, name: 'document.pdf');

      expect(fileLike.file, equals(testFile));
      expect(fileLike.name, equals('document.pdf'));
      expect(fileLike.size, equals(3));
    });

    test('streams file contents', () async {
      final content = utf8.encode('Hello from file!');
      await testFile.writeAsBytes(content);

      final fileLike = FileLikeFromFile(testFile, name: 'hello.txt');
      final chunks = <Uint8List>[];

      await for (final chunk in fileLike.stream()) {
        chunks.add(chunk);
      }

      expect(chunks.length, greaterThan(0));

      final reconstructed = <int>[];
      for (final chunk in chunks) {
        reconstructed.addAll(chunk);
      }
      expect(utf8.decode(reconstructed), equals('Hello from file!'));
    });

    test('preserves file path in name', () async {
      await testFile.writeAsBytes([]);
      final fileLike = FileLikeFromFile(
        testFile,
        name: 'docs/reports/2024/document.pdf',
      );

      expect(fileLike.name, equals('docs/reports/2024/document.pdf'));
    });

    test('respects custom chunk size', () async {
      final content = List.generate(1000, (i) => i % 256);
      await testFile.writeAsBytes(content);

      final fileLike = FileLikeFromFile(
        testFile,
        name: 'data.bin',
        chunkSize: 100,
      );

      final chunks = <Uint8List>[];
      await for (final chunk in fileLike.stream()) {
        chunks.add(chunk);
      }

      // Should have 10 chunks (1000 / 100)
      expect(chunks.length, equals(10));
      for (final chunk in chunks) {
        expect(chunk.length, equals(100));
      }
    });

    test('equality works correctly', () async {
      await testFile.writeAsBytes([1, 2, 3]);
      final file1 = FileLikeFromFile(testFile, name: 'file.txt');
      final file2 = FileLikeFromFile(testFile, name: 'file.txt');
      final file3 = FileLikeFromFile(testFile, name: 'other.txt');

      expect(file1, equals(file2));
      expect(file1, isNot(equals(file3)));
    });

    test('toString provides useful info', () async {
      await testFile.writeAsBytes(List.generate(2048, (i) => i));
      final fileLike = FileLikeFromFile(testFile, name: 'large.bin');

      final str = fileLike.toString();

      expect(str, contains('FileLikeFromFile'));
      expect(str, contains('large.bin'));
      expect(str, contains('2048'));
    });
  });

  group('Integration: File vs Memory', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storacha_test_');
      testFile = File('${tempDir.path}/test.dat');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('FileBlob and MemoryBlob produce same output', () async {
      final content = List.generate(10000, (i) => (i * 7) % 256);

      // Write to file
      await testFile.writeAsBytes(content);

      // Create both blob types
      final fileBlob = FileBlob(testFile, chunkSize: 1024);
      final memoryBlob = MemoryBlob(bytes: Uint8List.fromList(content));

      // Stream from file
      final fileChunks = <int>[];
      await for (final chunk in fileBlob.stream()) {
        fileChunks.addAll(chunk);
      }

      // Stream from memory
      final memoryChunks = <int>[];
      await for (final chunk in memoryBlob.stream()) {
        memoryChunks.addAll(chunk);
      }

      // Should produce identical output
      expect(fileChunks, equals(memoryChunks));
      expect(fileChunks, equals(content));
    });

    test('FileLikeFromFile and MemoryFile produce same output', () async {
      const text = 'The quick brown fox jumps over the lazy dog';
      final content = utf8.encode(text);

      await testFile.writeAsBytes(content);

      final fileVersion = FileLikeFromFile(testFile, name: 'test.txt');
      final memoryVersion = MemoryFile(
        name: 'test.txt',
        bytes: Uint8List.fromList(content),
      );

      // Stream both
      final fileData = <int>[];
      await for (final chunk in fileVersion.stream()) {
        fileData.addAll(chunk);
      }

      final memoryData = <int>[];
      await for (final chunk in memoryVersion.stream()) {
        memoryData.addAll(chunk);
      }

      expect(utf8.decode(fileData), equals(text));
      expect(utf8.decode(memoryData), equals(text));
      expect(fileData, equals(memoryData));
    });

    test('FileBlob handles concurrent streams', () async {
      final content = List.generate(5000, (i) => i % 256);
      await testFile.writeAsBytes(content);

      final blob = FileBlob(testFile, chunkSize: 1000);

      // Start two streams simultaneously
      final stream1 = blob.stream().toList();
      final stream2 = blob.stream().toList();

      final chunks1 = await stream1;
      final chunks2 = await stream2;

      // Both should work independently
      final data1 = chunks1.expand((c) => c).toList();
      final data2 = chunks2.expand((c) => c).toList();

      expect(data1, equals(content));
      expect(data2, equals(content));
    });
  });
}
