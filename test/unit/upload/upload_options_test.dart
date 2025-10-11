import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/upload/upload_options.dart';
import 'package:test/test.dart';

void main() {
  group('ProgressStatus', () {
    test('creates progress with loaded and total', () {
      final progress = ProgressStatus(loaded: 50, total: 100);

      expect(progress.loaded, equals(50));
      expect(progress.total, equals(100));
      expect(progress.percentage, equals(50.0));
    });

    test('handles unknown total', () {
      final progress = ProgressStatus(loaded: 1024, total: null);

      expect(progress.loaded, equals(1024));
      expect(progress.total, isNull);
      expect(progress.percentage, isNull);
    });

    test('includes URL if provided', () {
      final progress = ProgressStatus(
        loaded: 100,
        total: 200,
        url: 'https://upload.storacha.network/blob',
      );

      expect(progress.url, equals('https://upload.storacha.network/blob'));
    });

    test('calculates percentage correctly', () {
      expect(
        ProgressStatus(loaded: 0, total: 100).percentage,
        equals(0.0),
      );
      expect(
        ProgressStatus(loaded: 25, total: 100).percentage,
        equals(25.0),
      );
      expect(
        ProgressStatus(loaded: 100, total: 100).percentage,
        equals(100.0),
      );
    });

    test('toString with percentage', () {
      final progress = ProgressStatus(loaded: 512, total: 1024);
      final str = progress.toString();

      expect(str, contains('50.0%'));
      expect(str, contains('512/1024'));
    });

    test('toString without percentage', () {
      final progress = ProgressStatus(loaded: 2048, total: null);
      final str = progress.toString();

      expect(str, contains('2048'));
      expect(str, contains('loaded'));
      expect(str, isNot(contains('%')));
    });
  });

  group('UploadOptions', () {
    test('creates with defaults', () {
      const options = UploadOptions();

      expect(options.retries, isNull);
      expect(options.onUploadProgress, isNull);
      expect(options.shardSize, isNull);
      expect(options.rootCID, isNull);
      expect(options.dedupe, isTrue);
    });

    test('creates with custom values', () {
      final testData = Uint8List.fromList('test data'.codeUnits);
      final cid = CID.createV1(0x55, sha256Hash(testData));

      final options = UploadOptions(
        retries: 3,
        shardSize: 1024 * 1024,
        rootCID: cid,
        dedupe: false,
      );

      expect(options.retries, equals(3));
      expect(options.shardSize, equals(1024 * 1024));
      expect(options.rootCID, equals(cid));
      expect(options.dedupe, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      const original = UploadOptions(retries: 5, dedupe: false);
      final copied = original.copyWith(shardSize: 2048);

      expect(copied.retries, equals(5));
      expect(copied.dedupe, isFalse);
      expect(copied.shardSize, equals(2048));
    });

    test('copyWith updates specified fields', () {
      const original = UploadOptions(retries: 5);
      final copied = original.copyWith(retries: 10, dedupe: false);

      expect(copied.retries, equals(10));
      expect(copied.dedupe, isFalse);
    });
  });

  group('UploadFileOptions', () {
    test('creates with defaults', () {
      const options = UploadFileOptions();

      expect(options.retries, isNull);
      expect(options.chunkSize, isNull);
      expect(options.dedupe, isTrue);
    });

    test('creates with custom chunk size', () {
      const options = UploadFileOptions(
        chunkSize: 512 * 1024, // 512 KiB
      );

      expect(options.chunkSize, equals(512 * 1024));
    });

    test('copyWith works correctly', () {
      const original = UploadFileOptions(
        chunkSize: 256 * 1024,
        retries: 3,
      );
      final copied = original.copyWith(chunkSize: 512 * 1024);

      expect(copied.chunkSize, equals(512 * 1024));
      expect(copied.retries, equals(3));
    });

    test('includes base upload options', () {
      const options = UploadFileOptions(
        retries: 7,
        shardSize: 100 * 1024 * 1024,
        dedupe: false,
      );

      expect(options.retries, equals(7));
      expect(options.shardSize, equals(100 * 1024 * 1024));
      expect(options.dedupe, isFalse);
    });
  });

  group('UploadDirectoryOptions', () {
    test('creates with defaults', () {
      const options = UploadDirectoryOptions();

      expect(options.retries, isNull);
      expect(options.chunkSize, isNull);
      expect(options.customOrder, isFalse);
      expect(options.dedupe, isTrue);
    });

    test('creates with custom order', () {
      const options = UploadDirectoryOptions(customOrder: true);

      expect(options.customOrder, isTrue);
    });

    test('copyWith works correctly', () {
      const original = UploadDirectoryOptions(
        customOrder: false,
        chunkSize: 256 * 1024,
      );
      final copied = original.copyWith(customOrder: true);

      expect(copied.customOrder, isTrue);
      expect(copied.chunkSize, equals(256 * 1024));
    });

    test('includes base upload options', () {
      const options = UploadDirectoryOptions(
        retries: 5,
        shardSize: 50 * 1024 * 1024,
        dedupe: false,
        customOrder: true,
      );

      expect(options.retries, equals(5));
      expect(options.shardSize, equals(50 * 1024 * 1024));
      expect(options.dedupe, isFalse);
      expect(options.customOrder, isTrue);
    });
  });

  group('Integration', () {
    test('progress callback can be used', () {
      var lastStatus = ProgressStatus(loaded: 0, total: 100);

      final options = UploadOptions(
        onUploadProgress: (status) {
          lastStatus = status;
        },
      );

      // Simulate progress updates
      options.onUploadProgress
          ?.call(ProgressStatus(loaded: 25, total: 100));
      expect(lastStatus.percentage, equals(25.0));

      options.onUploadProgress
          ?.call(ProgressStatus(loaded: 100, total: 100));
      expect(lastStatus.percentage, equals(100.0));
    });

    test('realistic upload configuration', () {
      const options = UploadFileOptions(
        retries: 5,
        shardSize: 100 * 1024 * 1024, // 100 MB shards
        chunkSize: 256 * 1024, // 256 KiB chunks
        dedupe: true,
      );

      expect(options.retries, equals(5));
      expect(options.shardSize, equals(104857600));
      expect(options.chunkSize, equals(262144));
      expect(options.dedupe, isTrue);
    });

    test('directory upload with preserved order', () {
      const options = UploadDirectoryOptions(
        customOrder: true,
        chunkSize: 128 * 1024,
        dedupe: false,
      );

      expect(options.customOrder, isTrue);
      expect(options.chunkSize, equals(128 * 1024));
      expect(options.dedupe, isFalse);
    });
  });
}
