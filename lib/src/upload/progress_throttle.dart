// ignore_for_file: sort_constructors_first

import 'upload_options.dart';

/// Throttles progress callbacks to maintain 60 FPS UI performance.
///
/// On mobile devices, excessive UI updates can cause frame drops and poor
/// user experience. This class ensures progress callbacks fire at a maximum
/// rate, typically matching the display refresh rate (60 FPS = ~16ms).
///
/// **Benefits**:
/// - 🎨 Smooth UI: No frame drops during uploads
/// - 🔋 Battery efficient: Less CPU wakeups for UI updates
/// - 📱 Mobile optimized: Respects iOS/Android rendering constraints
///
/// Example:
/// ```dart
/// final throttle = ThrottledProgressCallback();
///
/// await client.uploadFile(
///   blob,
///   options: UploadFileOptions(
///     onUploadProgress: throttle.wrap((status) {
///       setState(() => progress = status.percentage ?? 0);
///     }),
///   ),
/// );
/// ```
class ThrottledProgressCallback {
  /// Creates a throttled progress callback.
  ///
  /// [minInterval] - Minimum time between callbacks (default 16ms = 60 FPS)
  ThrottledProgressCallback({
    this.minInterval = const Duration(milliseconds: 16),
  });

  /// Minimum time between progress callbacks.
  ///
  /// Default is 16ms to achieve 60 FPS:
  /// - 60 FPS = 1000ms / 60 = ~16.67ms per frame
  ///
  /// You can adjust this for different scenarios:
  /// - 30 FPS: `Duration(milliseconds: 33)`
  /// - 120 FPS: `Duration(milliseconds: 8)` (for high-refresh displays)
  final Duration minInterval;

  DateTime? _lastUpdate;

  /// Wraps a progress callback to throttle its invocations.
  ///
  /// The wrapped callback will only be invoked if enough time has passed
  /// since the last invocation, or if this is the first invocation.
  ///
  /// Example:
  /// ```dart
  /// final throttle = ThrottledProgressCallback();
  ///
  /// final wrappedCallback = throttle.wrap((status) {
  ///   print('Progress: ${status.percentage}%');
  /// });
  ///
  /// // Use in upload options
  /// UploadFileOptions(onUploadProgress: wrappedCallback)
  /// ```
  void Function(ProgressStatus) wrap(
    void Function(ProgressStatus) callback,
  ) {
    return (status) {
      final now = DateTime.now();

      // Always allow first update
      if (_lastUpdate == null) {
        callback(status);
        _lastUpdate = now;
        return;
      }

      // Check if enough time has passed
      final elapsed = now.difference(_lastUpdate!);
      if (elapsed >= minInterval) {
        callback(status);
        _lastUpdate = now;
      }

      // Always allow 100% completion updates
      if (status.percentage == 100.0) {
        callback(status);
        _lastUpdate = now;
      }
    };
  }

  /// Resets the throttle state.
  ///
  /// Call this between uploads to ensure the first progress update of a new
  /// upload is not throttled.
  void reset() {
    _lastUpdate = null;
  }
}

/// A more advanced throttled callback that guarantees final updates.
///
/// Unlike [ThrottledProgressCallback], this version ensures that the final
/// state is always delivered, even if it would normally be throttled.
///
/// **Use cases**:
/// - Critical final states (upload complete, error occurred)
/// - Animations that need exact completion timing
/// - State machines that depend on final values
///
/// Example:
/// ```dart
/// final throttle = GuaranteedProgressCallback();
///
/// await client.uploadFile(
///   blob,
///   options: UploadFileOptions(
///     onUploadProgress: throttle.wrap(
///       (status) => print('${status.percentage}%'),
///       isFinal: (status) => status.percentage == 100.0,
///     ),
///   ),
/// );
/// ```
class GuaranteedProgressCallback {
  /// Creates a guaranteed progress callback.
  GuaranteedProgressCallback({
    this.minInterval = const Duration(milliseconds: 16),
  });

  /// Minimum time between progress callbacks.
  final Duration minInterval;

  DateTime? _lastUpdate;
  ProgressStatus? _pendingStatus;

  /// Wraps a progress callback with guaranteed delivery of final states.
  ///
  /// [callback] - The function to call with progress updates
  /// [isFinal] - Optional function to determine if a status is final
  ///             (defaults to checking for 100% completion)
  void Function(ProgressStatus) wrap(
    void Function(ProgressStatus) callback, {
    bool Function(ProgressStatus)? isFinal,
  }) {
    final finalCheck = isFinal ?? (status) => status.percentage == 100.0;

    return (status) {
      final now = DateTime.now();

      // Always deliver final states immediately
      if (finalCheck(status)) {
        callback(status);
        _lastUpdate = now;
        _pendingStatus = null;
        return;
      }

      // First update always goes through
      if (_lastUpdate == null) {
        callback(status);
        _lastUpdate = now;
        _pendingStatus = null;
        return;
      }

      // Check if enough time has passed
      final elapsed = now.difference(_lastUpdate!);
      if (elapsed >= minInterval) {
        callback(status);
        _lastUpdate = now;
        _pendingStatus = null;
      } else {
        // Store pending update for potential delivery
        _pendingStatus = status;
      }
    };
  }

  /// Flushes any pending progress update.
  ///
  /// Call this to force delivery of a pending status that was throttled.
  /// Useful when pausing or canceling an upload.
  void flush(void Function(ProgressStatus) callback) {
    if (_pendingStatus != null) {
      callback(_pendingStatus!);
      _pendingStatus = null;
      _lastUpdate = DateTime.now();
    }
  }

  /// Resets the throttle state.
  void reset() {
    _lastUpdate = null;
    _pendingStatus = null;
  }
}

/// Utility for batching multiple progress updates into aggregated reports.
///
/// Useful when uploading multiple files simultaneously and wanting to show
/// combined progress without overwhelming the UI.
///
/// Example:
/// ```dart
/// final batcher = ProgressBatcher(maxBatchSize: 5);
///
/// // Upload multiple files
/// for (final file in files) {
///   await client.uploadFile(
///     file,
///     options: UploadFileOptions(
///       onUploadProgress: (status) {
///         batcher.add(file.name, status);
///       },
///     ),
///   );
/// }
///
/// // Get combined progress
/// final overall = batcher.getOverallProgress();
/// print('Total progress: ${overall.percentage}%');
/// ```
class ProgressBatcher {
  /// Creates a progress batcher.
  ProgressBatcher({
    this.maxBatchSize = 10,
    this.updateInterval = const Duration(milliseconds: 100),
  });

  /// Maximum number of individual progresses to track.
  final int maxBatchSize;

  /// Minimum time between aggregated updates.
  final Duration updateInterval;

  final Map<String, ProgressStatus> _progresses = {};
  DateTime? _lastAggregatedUpdate;

  /// Adds a progress update for a specific item.
  void add(String itemId, ProgressStatus status) {
    _progresses[itemId] = status;

    // Trim if exceeds max size (FIFO)
    if (_progresses.length > maxBatchSize) {
      final firstKey = _progresses.keys.first;
      _progresses.remove(firstKey);
    }
  }

  /// Gets the overall aggregated progress.
  ///
  /// Returns a [ProgressStatus] representing the combined progress of all
  /// tracked items.
  ProgressStatus getOverallProgress() {
    if (_progresses.isEmpty) {
      return const ProgressStatus(loaded: 0, total: 0);
    }

    var totalLoaded = 0;
    var totalSize = 0;

    for (final status in _progresses.values) {
      totalLoaded += status.loaded;
      if (status.total != null) {
        totalSize += status.total!;
      }
    }

    return ProgressStatus(
      loaded: totalLoaded,
      total: totalSize > 0 ? totalSize : null,
    );
  }

  /// Checks if enough time has passed to emit an aggregated update.
  bool shouldUpdate() {
    if (_lastAggregatedUpdate == null) return true;

    final elapsed = DateTime.now().difference(_lastAggregatedUpdate!);
    return elapsed >= updateInterval;
  }

  /// Marks that an aggregated update was emitted.
  void markUpdated() {
    _lastAggregatedUpdate = DateTime.now();
  }

  /// Clears all tracked progresses.
  void clear() {
    _progresses.clear();
    _lastAggregatedUpdate = null;
  }

  /// Removes progress for a specific item.
  void remove(String itemId) {
    _progresses.remove(itemId);
  }

  /// Gets the number of items currently tracked.
  int get itemCount => _progresses.length;
}

