import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../multiformats/cid.dart';

/// UnixFS data types.
enum UnixFSType {
  /// Regular file
  file,

  /// Directory
  directory,

  /// Symbolic link
  symlink,
}

/// A UnixFS node representing file/directory metadata.
@immutable
class UnixFSNode {
  /// Creates a UnixFS node.
  const UnixFSNode({
    required this.type,
    this.data,
    this.filesize,
    this.blocksizes = const [],
  });

  /// The type of UnixFS node.
  final UnixFSType type;

  /// Optional data payload (for files).
  final Uint8List? data;

  /// Total file size (for files).
  final int? filesize;

  /// Sizes of child blocks (for chunked files).
  final List<int> blocksizes;
}

/// An IPLD block with its CID and data.
@immutable
class IPLDBlock {
  /// Creates an IPLD block.
  const IPLDBlock({
    required this.cid,
    required this.bytes,
  });

  /// The Content Identifier of this block.
  final CID cid;

  /// The encoded block data.
  final Uint8List bytes;
}

/// Result of encoding a file/directory to UnixFS.
@immutable
class UnixFSEncodeResult {
  /// Creates an encode result.
  const UnixFSEncodeResult({
    required this.rootCID,
    required this.blocks,
  });

  /// The root CID of the encoded data.
  final CID rootCID;

  /// All IPLD blocks generated during encoding.
  final List<IPLDBlock> blocks;
}

/// Options for UnixFS encoding.
@immutable
class UnixFSEncodeOptions {
  /// Creates encoding options.
  const UnixFSEncodeOptions({
    this.chunkSize = 256 * 1024, // 256 KiB default
    this.maxChildrenPerNode = 174, // Standard UnixFS
    this.rawLeaves = true,
  });

  /// Size of each file chunk.
  final int chunkSize;

  /// Maximum children per intermediate node.
  final int maxChildrenPerNode;

  /// Whether to use raw codec for leaf nodes.
  final bool rawLeaves;
}

