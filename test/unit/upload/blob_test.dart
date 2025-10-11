import 'dart:convert';
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
}
