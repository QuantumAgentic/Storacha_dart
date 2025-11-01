import 'package:meta/meta.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';

/// Progress status for upload operations.
///
/// Reports the current state of data transfer during an upload.
@immutable
class ProgressStatus {
  /// Creates a progress status.
  const ProgressStatus({
    required this.loaded,
    required this.total,
    this.url,
  });

  /// Number of bytes loaded so far.
  final int loaded;

  /// Total number of bytes to load, if known.
  final int? total;

  /// URL being uploaded to, if available.
  final String? url;

  /// Progress as a percentage (0-100), or null if total is unknown.
  double? get percentage {
    if (total == null || total == 0) {
      return null;
    }
    return (loaded / total!) * 100;
  }

  @override
  String toString() {
    if (percentage != null) {
      return 'ProgressStatus(${percentage!.toStringAsFixed(1)}% - '
          '$loaded/$total bytes)';
    }
    return 'ProgressStatus($loaded bytes loaded)';
  }
}

/// Callback for upload progress updates.
typedef ProgressCallback = void Function(ProgressStatus status);

/// Options for sharding large uploads into multiple CAR files.
@immutable
class ShardingOptions {
  /// Creates sharding options.
  const ShardingOptions({
    this.shardSize,
    this.rootCID,
  });

  /// Target shard size in bytes.
  ///
  /// Actual CAR file size may be larger due to headers and encoding overhead.
  /// Default is typically 100MB (104857600 bytes).
  final int? shardSize;

  /// Root CID of the DAG contained in the shards.
  ///
  /// By default, the last block is assumed to be the DAG root. Set this to
  /// override with a specific CID.
  final CID? rootCID;
}

/// Base options for all upload operations.
@immutable
class UploadOptions {
  /// Creates upload options.
  const UploadOptions({
    this.retries,
    this.onUploadProgress,
    this.shardSize,
    this.rootCID,
    this.dedupe = true,
  });

  /// Number of times to retry failed requests.
  ///
  /// Default is typically 5 retries.
  final int? retries;

  /// Callback for upload progress updates.
  final ProgressCallback? onUploadProgress;

  /// Target shard size in bytes.
  ///
  /// See [ShardingOptions.shardSize] for details.
  final int? shardSize;

  /// Root CID override.
  ///
  /// See [ShardingOptions.rootCID] for details.
  final CID? rootCID;

  /// Whether to deduplicate repeated blocks during upload.
  ///
  /// When `true` (default), duplicate blocks are only uploaded once, reducing
  /// upload size. When `false`, all blocks are uploaded even if duplicated,
  /// which may increase upload size but reduces memory overhead.
  final bool dedupe;

  /// Creates a copy with modified fields.
  UploadOptions copyWith({
    int? retries,
    ProgressCallback? onUploadProgress,
    int? shardSize,
    CID? rootCID,
    bool? dedupe,
  }) =>
      UploadOptions(
        retries: retries ?? this.retries,
        onUploadProgress: onUploadProgress ?? this.onUploadProgress,
        shardSize: shardSize ?? this.shardSize,
        rootCID: rootCID ?? this.rootCID,
        dedupe: dedupe ?? this.dedupe,
      );
}

/// Options specific to file uploads.
@immutable
class UploadFileOptions extends UploadOptions {
  /// Creates file upload options.
  const UploadFileOptions({
    super.retries,
    super.onUploadProgress,
    super.shardSize,
    super.rootCID,
    super.dedupe,
    this.chunkSize,
    this.creatorWallet,
    this.ipnsName,
    this.agentName,
  });

  /// Size of UnixFS chunks in bytes.
  ///
  /// Files are split into chunks of this size for efficient storage and
  /// retrieval. Default is typically 262144 bytes (256 KiB).
  final int? chunkSize;

  /// Solana creator wallet address (for agent registry)
  final String? creatorWallet;

  /// IPNS name for agent manifest (for agent registry)
  final String? ipnsName;

  /// Agent name (for logging/metadata)
  final String? agentName;

  @override
  UploadFileOptions copyWith({
    int? retries,
    ProgressCallback? onUploadProgress,
    int? shardSize,
    CID? rootCID,
    bool? dedupe,
    int? chunkSize,
    String? creatorWallet,
    String? ipnsName,
    String? agentName,
  }) =>
      UploadFileOptions(
        retries: retries ?? this.retries,
        onUploadProgress: onUploadProgress ?? this.onUploadProgress,
        shardSize: shardSize ?? this.shardSize,
        rootCID: rootCID ?? this.rootCID,
        dedupe: dedupe ?? this.dedupe,
        chunkSize: chunkSize ?? this.chunkSize,
        creatorWallet: creatorWallet ?? this.creatorWallet,
        ipnsName: ipnsName ?? this.ipnsName,
        agentName: agentName ?? this.agentName,
      );
}

/// Options specific to directory uploads.
@immutable
class UploadDirectoryOptions extends UploadOptions {
  /// Creates directory upload options.
  const UploadDirectoryOptions({
    super.retries,
    super.onUploadProgress,
    super.shardSize,
    super.rootCID,
    super.dedupe,
    this.chunkSize,
    this.customOrder = false,
  });

  /// Size of UnixFS chunks in bytes.
  ///
  /// See [UploadFileOptions.chunkSize] for details.
  final int? chunkSize;

  /// Whether files are already ordered in a custom way.
  ///
  /// When `true`, the upload preserves the exact order of files provided.
  /// When `false` (default), files may be reordered for optimization.
  final bool customOrder;

  @override
  UploadDirectoryOptions copyWith({
    int? retries,
    ProgressCallback? onUploadProgress,
    int? shardSize,
    CID? rootCID,
    bool? dedupe,
    int? chunkSize,
    bool? customOrder,
  }) =>
      UploadDirectoryOptions(
        retries: retries ?? this.retries,
        onUploadProgress: onUploadProgress ?? this.onUploadProgress,
        shardSize: shardSize ?? this.shardSize,
        rootCID: rootCID ?? this.rootCID,
        dedupe: dedupe ?? this.dedupe,
        chunkSize: chunkSize ?? this.chunkSize,
        customOrder: customOrder ?? this.customOrder,
      );
}
