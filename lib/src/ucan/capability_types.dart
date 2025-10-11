/// Types for Storacha capabilities
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';

/// Blob descriptor for space/blob/add capability
@immutable
class BlobDescriptor {
  const BlobDescriptor({
    required this.digest,
    required this.size,
  });

  /// Multihash digest of the blob (typically SHA-256)
  final Uint8List digest;

  /// Size of the blob in bytes
  final int size;

  /// Convert to JSON for UCAN encoding
  Map<String, dynamic> toJson() => {
        'digest': digest,
        'size': size,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobDescriptor &&
          runtimeType == other.runtimeType &&
          _bytesEqual(digest, other.digest) &&
          size == other.size;

  @override
  int get hashCode => Object.hash(Object.hashAll(digest), size);

  @override
  String toString() => 'BlobDescriptor(digest: ${digest.length} bytes, '
      'size: $size)';

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Allocation information from space/blob/add response
@immutable
class BlobAllocation {
  const BlobAllocation({
    required this.allocated,
    this.url,
    this.headers,
  });

  /// Whether the blob was newly allocated (true) or already exists (false)
  final bool allocated;

  /// URL where to PUT the blob (if allocated)
  final String? url;

  /// HTTP headers to use for PUT (if allocated)
  final Map<String, String>? headers;

  factory BlobAllocation.fromJson(Map<String, dynamic> json) {
    final allocated = json['allocated'] as bool? ?? false;
    final site = json['site'] as Map<String, dynamic>?;

    return BlobAllocation(
      allocated: allocated,
      url: site?['url'] as String?,
      headers: site?['headers'] != null
          ? (site!['headers'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobAllocation &&
          runtimeType == other.runtimeType &&
          allocated == other.allocated &&
          url == other.url;

  @override
  int get hashCode => Object.hash(allocated, url);

  @override
  String toString() => 'BlobAllocation(allocated: $allocated, url: $url)';
}

/// Upload descriptor for upload/add capability
@immutable
class UploadDescriptor {
  const UploadDescriptor({
    required this.root,
    this.shards,
  });

  /// Root CID of the DAG
  final CID root;

  /// Optional list of shard CIDs (CAR files)
  final List<CID>? shards;

  /// Convert to JSON for UCAN encoding
  Map<String, dynamic> toJson() => {
        'root': root.toJson(),
        if (shards != null) 'shards': shards!.map((s) => s.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadDescriptor &&
          runtimeType == other.runtimeType &&
          root == other.root;

  @override
  int get hashCode => root.hashCode;

  @override
  String toString() => 'UploadDescriptor(root: $root, '
      'shards: ${shards?.length ?? 0})';
}

/// Response from upload/add invocation
@immutable
class UploadResult {
  const UploadResult({
    required this.root,
    this.shards,
  });

  /// Root CID that was registered
  final CID root;

  /// Shard CIDs that were registered
  final List<CID>? shards;

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    // Parse root CID
    final rootJson = json['root'];
    final root = rootJson is Map<String, dynamic>
        ? CID.fromJson(rootJson)
        : CID.parse(rootJson.toString());

    // Parse optional shards
    final shardsJson = json['shards'] as List?;
    final shards = shardsJson
        ?.map((s) => s is Map<String, dynamic>
            ? CID.fromJson(s)
            : CID.parse(s.toString()))
        .toList();

    return UploadResult(root: root, shards: shards);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadResult &&
          runtimeType == other.runtimeType &&
          root == other.root;

  @override
  int get hashCode => root.hashCode;

  @override
  String toString() => 'UploadResult(root: $root, shards: ${shards?.length})';
}

