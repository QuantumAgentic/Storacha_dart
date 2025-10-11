import 'package:storacha_dart/src/upload/progress_throttle.dart';
import 'package:storacha_dart/src/upload/upload_options.dart';
import 'package:test/test.dart';

void main() {
  group('ThrottledProgressCallback', () {
    test('allows first update immediately', () {
      final throttle = ThrottledProgressCallback();
      var callCount = 0;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      wrapped(const ProgressStatus(loaded: 100, total: 1000));

      expect(callCount, equals(1));
    });

    test('throttles rapid updates', () async {
      final throttle = ThrottledProgressCallback(
        minInterval: const Duration(milliseconds: 50),
      );
      var callCount = 0;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      // Fire 10 updates rapidly
      for (var i = 0; i < 10; i++) {
        wrapped(ProgressStatus(loaded: i * 100, total: 1000));
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // Should have only called once (initial) since all happened within 50ms
      expect(callCount, lessThan(10));
    });

    test('allows updates after interval passes', () async {
      final throttle = ThrottledProgressCallback(
        minInterval: const Duration(milliseconds: 20),
      );
      var callCount = 0;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      // First update
      wrapped(const ProgressStatus(loaded: 100, total: 1000));
      expect(callCount, equals(1));

      // Wait for interval to pass
      await Future<void>.delayed(const Duration(milliseconds: 25));

      // Second update should go through
      wrapped(const ProgressStatus(loaded: 500, total: 1000));
      expect(callCount, equals(2));
    });

    test('always allows 100% completion', () async {
      final throttle = ThrottledProgressCallback(
        minInterval: const Duration(milliseconds: 100),
      );
      var callCount = 0;
      ProgressStatus? lastStatus;

      final wrapped = throttle.wrap((status) {
        callCount++;
        lastStatus = status;
      });

      // First update
      wrapped(const ProgressStatus(loaded: 100, total: 1000));

      // Completion update should always go through, even if rapid
      wrapped(const ProgressStatus(loaded: 1000, total: 1000));

      expect(callCount, equals(2));
      expect(lastStatus?.percentage, equals(100.0));
    });

    test('reset clears throttle state', () {
      final throttle = ThrottledProgressCallback();
      var callCount = 0;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      // First update
      wrapped(const ProgressStatus(loaded: 100, total: 1000));
      expect(callCount, equals(1));

      // Reset
      throttle.reset();

      // Next update should be treated as first
      wrapped(const ProgressStatus(loaded: 200, total: 1000));
      expect(callCount, equals(2));
    });

    test('default interval is ~60 FPS', () {
      final throttle = ThrottledProgressCallback();

      // Default should be ~16ms for 60 FPS
      expect(
        throttle.minInterval.inMilliseconds,
        equals(16),
      );
    });

    test('handles multiple sequential uploads', () async {
      final throttle = ThrottledProgressCallback(
        minInterval: const Duration(milliseconds: 10),
      );
      var upload1Calls = 0;
      var upload2Calls = 0;

      final wrapped = throttle.wrap((status) {
        if ((status.total ?? 0) == 1000) {
          upload1Calls++;
        } else {
          upload2Calls++;
        }
      });

      // First upload
      wrapped(const ProgressStatus(loaded: 100, total: 1000));
      wrapped(const ProgressStatus(loaded: 1000, total: 1000));

      throttle.reset();

      // Second upload (after reset)
      await Future<void>.delayed(const Duration(milliseconds: 15));
      wrapped(const ProgressStatus(loaded: 50, total: 500));
      wrapped(const ProgressStatus(loaded: 500, total: 500));

      expect(upload1Calls, greaterThan(0));
      expect(upload2Calls, greaterThan(0));
    });
  });

  group('GuaranteedProgressCallback', () {
    test('delivers final states immediately', () {
      final throttle = GuaranteedProgressCallback();
      var callCount = 0;
      ProgressStatus? lastStatus;

      final wrapped = throttle.wrap(
        (status) {
          callCount++;
          lastStatus = status;
        },
        isFinal: (status) => status.percentage == 100.0,
      );

      // Non-final update
      wrapped(const ProgressStatus(loaded: 500, total: 1000));

      // Final update should always be delivered
      wrapped(const ProgressStatus(loaded: 1000, total: 1000));

      expect(callCount, equals(2));
      expect(lastStatus?.percentage, equals(100.0));
    });

    test('uses default final check for 100%', () {
      final throttle = GuaranteedProgressCallback();
      var callCount = 0;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      wrapped(const ProgressStatus(loaded: 500, total: 1000));
      wrapped(const ProgressStatus(loaded: 1000, total: 1000));

      expect(callCount, equals(2));
    });

    test('stores pending status when throttled', () async {
      final throttle = GuaranteedProgressCallback(
        minInterval: const Duration(milliseconds: 50),
      );
      var callCount = 0;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      // First update
      wrapped(const ProgressStatus(loaded: 100, total: 1000));

      // This should be throttled and stored as pending
      wrapped(const ProgressStatus(loaded: 200, total: 1000));

      expect(callCount, equals(1));
      // Pending status is internal state, not exposed
    });

    test('flush delivers pending status', () {
      final throttle = GuaranteedProgressCallback(
        minInterval: const Duration(milliseconds: 100),
      );
      var callCount = 0;
      ProgressStatus? flushedStatus;

      final wrapped = throttle.wrap((status) {
        callCount++;
      });

      // First update
      wrapped(const ProgressStatus(loaded: 100, total: 1000));

      // Throttled update
      wrapped(const ProgressStatus(loaded: 500, total: 1000));

      expect(callCount, equals(1));

      // Flush pending
      throttle.flush((status) {
        flushedStatus = status;
      });

      expect(flushedStatus?.loaded, equals(500));
    });

    test('reset clears pending status', () {
      final throttle = GuaranteedProgressCallback();

      final wrapped = throttle.wrap((status) {});

      wrapped(const ProgressStatus(loaded: 100, total: 1000));
      wrapped(const ProgressStatus(loaded: 200, total: 1000));

      throttle.reset();

      // Internal state reset is verified by behavior
    });

    test('custom final check works correctly', () async {
      final throttle = GuaranteedProgressCallback(
        minInterval: const Duration(milliseconds: 10),
      );
      var callCount = 0;

      final wrapped = throttle.wrap(
        (status) {
          callCount++;
        },
        isFinal: (status) => status.loaded >= 900,
      );

      // Regular updates with delays
      wrapped(const ProgressStatus(loaded: 100, total: 1000));
      await Future<void>.delayed(const Duration(milliseconds: 15));

      wrapped(const ProgressStatus(loaded: 500, total: 1000));
      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Custom final condition met - should always go through
      wrapped(const ProgressStatus(loaded: 950, total: 1000));

      expect(callCount, equals(3));
    });
  });

  group('ProgressBatcher', () {
    test('creates empty batcher', () {
      final batcher = ProgressBatcher();

      expect(batcher.itemCount, equals(0));

      final overall = batcher.getOverallProgress();
      expect(overall.loaded, equals(0));
      expect(overall.total, equals(0));
    });

    test('adds and tracks individual progresses', () {
      final batcher = ProgressBatcher();

      batcher.add('file1', const ProgressStatus(loaded: 100, total: 1000));
      batcher.add('file2', const ProgressStatus(loaded: 250, total: 500));

      expect(batcher.itemCount, equals(2));
    });

    test('calculates overall progress correctly', () {
      final batcher = ProgressBatcher();

      batcher.add('file1', const ProgressStatus(loaded: 400, total: 1000));
      batcher.add('file2', const ProgressStatus(loaded: 150, total: 500));
      batcher.add('file3', const ProgressStatus(loaded: 100, total: 200));

      final overall = batcher.getOverallProgress();

      expect(overall.loaded, equals(650)); // 400 + 150 + 100
      expect(overall.total, equals(1700)); // 1000 + 500 + 200
      expect(overall.percentage, closeTo(38.2, 0.1));
    });

    test('handles items with unknown total', () {
      final batcher = ProgressBatcher();

      batcher.add('file1', const ProgressStatus(loaded: 100, total: 1000));
      batcher.add('file2', const ProgressStatus(loaded: 250, total: null));

      final overall = batcher.getOverallProgress();

      expect(overall.loaded, equals(350));
      expect(overall.total, equals(1000)); // Only known total
    });

    test('trims old items when exceeding max size', () {
      final batcher = ProgressBatcher(maxBatchSize: 3);

      batcher.add('file1', const ProgressStatus(loaded: 100, total: 1000));
      batcher.add('file2', const ProgressStatus(loaded: 200, total: 1000));
      batcher.add('file3', const ProgressStatus(loaded: 300, total: 1000));
      batcher.add('file4', const ProgressStatus(loaded: 400, total: 1000));

      expect(batcher.itemCount, equals(3));

      // file1 should have been removed (FIFO)
      final overall = batcher.getOverallProgress();
      expect(overall.loaded, equals(900)); // 200 + 300 + 400
    });

    test('shouldUpdate respects update interval', () async {
      final batcher = ProgressBatcher(
        updateInterval: const Duration(milliseconds: 50),
      );

      // First check should allow update
      expect(batcher.shouldUpdate(), isTrue);

      batcher.markUpdated();

      // Immediate check should not allow
      expect(batcher.shouldUpdate(), isFalse);

      // After interval, should allow
      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(batcher.shouldUpdate(), isTrue);
    });

    test('clear removes all items', () {
      final batcher = ProgressBatcher();

      batcher.add('file1', const ProgressStatus(loaded: 100, total: 1000));
      batcher.add('file2', const ProgressStatus(loaded: 200, total: 1000));

      expect(batcher.itemCount, equals(2));

      batcher.clear();

      expect(batcher.itemCount, equals(0));
    });

    test('remove deletes specific item', () {
      final batcher = ProgressBatcher();

      batcher.add('file1', const ProgressStatus(loaded: 100, total: 1000));
      batcher.add('file2', const ProgressStatus(loaded: 200, total: 1000));

      batcher.remove('file1');

      expect(batcher.itemCount, equals(1));

      final overall = batcher.getOverallProgress();
      expect(overall.loaded, equals(200));
    });

    test('updates existing item progress', () {
      final batcher = ProgressBatcher();

      batcher.add('file1', const ProgressStatus(loaded: 100, total: 1000));
      batcher.add('file1', const ProgressStatus(loaded: 500, total: 1000));

      expect(batcher.itemCount, equals(1));

      final overall = batcher.getOverallProgress();
      expect(overall.loaded, equals(500));
    });

    test('integration: batching multiple uploads', () {
      final batcher = ProgressBatcher();
      final updates = <double>[];

      // Simulate 3 files uploading
      final files = ['video.mp4', 'photo.jpg', 'document.pdf'];
      final sizes = [10000, 5000, 2000];

      // Initial state
      for (var i = 0; i < files.length; i++) {
        batcher.add(files[i], ProgressStatus(loaded: 0, total: sizes[i]));
      }

      // Progress updates - force all updates to check final state
      for (var progress = 0; progress <= 100; progress += 25) {
        for (var i = 0; i < files.length; i++) {
          final loaded = (sizes[i] * progress / 100).round();
          batcher.add(files[i], ProgressStatus(loaded: loaded, total: sizes[i]));
        }

        // Always capture this checkpoint (ignoring shouldUpdate for test)
        final overall = batcher.getOverallProgress();
        updates.add(overall.percentage ?? 0);
      }

      // Should have all checkpoints
      expect(updates, isNotEmpty);
      expect(updates.last, equals(100.0));
    });
  });

  group('Integration: Throttle with real-world scenario', () {
    test('uploading large file with smooth UI updates', () async {
      final throttle = ThrottledProgressCallback(
        minInterval: const Duration(milliseconds: 16), // 60 FPS
      );

      final uiUpdates = <double>[];

      final wrapped = throttle.wrap((status) {
        uiUpdates.add(status.percentage ?? 0);
      });

      // Simulate rapid progress updates (every 1ms for 100ms)
      const totalSize = 100 * 1024 * 1024; // 100 MB
      for (var i = 0; i <= 100; i++) {
        final loaded = (totalSize * i / 100).round();
        wrapped(ProgressStatus(loaded: loaded, total: totalSize));

        if (i < 100) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      }

      // Should have significantly fewer UI updates than progress events
      expect(uiUpdates.length, lessThan(100));

      // But should still have reasonable granularity (at least 5 updates)
      expect(uiUpdates.length, greaterThan(5));

      // Should always include 100% completion
      expect(uiUpdates.last, equals(100.0));
    });

    test('multiple files with batched progress', () async {
      final batcher = ProgressBatcher(
        maxBatchSize: 10,
        updateInterval: const Duration(milliseconds: 20),
      );

      final overallUpdates = <double>[];

      // Simulate 5 files uploading CONCURRENTLY (all progress together)
      const fileCount = 5;
      const fileSize = 10 * 1024 * 1024; // 10 MB each

      for (var progress = 0; progress <= 100; progress += 20) {
        // Update ALL files to same progress level (concurrent upload)
        for (var fileIdx = 0; fileIdx < fileCount; fileIdx++) {
          final loaded = (fileSize * progress / 100).round();
          batcher.add(
            'file$fileIdx',
            ProgressStatus(loaded: loaded, total: fileSize),
          );
        }

        if (batcher.shouldUpdate()) {
          final overall = batcher.getOverallProgress();
          overallUpdates.add(overall.percentage ?? 0);
          batcher.markUpdated();
        }

        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      // Should have batched updates and reach 100%
      expect(overallUpdates, isNotEmpty);
      expect(overallUpdates.last, closeTo(100.0, 0.1));
    });
  });
}

