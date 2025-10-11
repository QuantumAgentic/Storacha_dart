import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/upload/blob.dart';

import 'file_chunker.dart';
import 'protobuf_encoder.dart';
import 'unixfs_types.dart';

/// Encodes files and directories into UnixFS IPLD DAGs.
///
/// This encoder creates IPLD blocks following the UnixFS specification.
/// It supports:
/// - Small files (< chunk size): Single raw block
/// - Medium files: Root node + raw leaf blocks
/// - Large files: Balanced tree with intermediate nodes (future)
/// - Directories: DAG-PB nodes with links to children (future)
class UnixFSEncoder {
  /// Creates a UnixFS encoder with the given options.
  const UnixFSEncoder({
    this.options = const UnixFSEncodeOptions(),
  });

  /// Encoding options.
  final UnixFSEncodeOptions options;

  /// Encodes a file into a UnixFS DAG.
  ///
  /// For small files (<= chunkSize), returns a single raw block.
  /// For larger files, creates a root DAG-PB node with links to raw chunks.
  ///
  /// Returns a [UnixFSEncodeResult] containing the root CID and all blocks.
  Future<UnixFSEncodeResult> encodeFile(BlobLike file) async {
    final fileSize = file.size;

    // If size is known and small, encode as single block
    if (fileSize != null && fileSize <= options.chunkSize) {
      return _encodeSingleBlock(file);
    }

    // If size is unknown or large, use chunked encoding
    // (chunked encoding will handle single block case if needed)
    return _encodeChunkedFile(file, fileSize);
  }

  /// Encodes a small file as a single raw block.
  Future<UnixFSEncodeResult> _encodeSingleBlock(BlobLike file) async {
    // Read the entire file (it's small)
    final bytes = await file.stream().fold<BytesBuilder>(
      BytesBuilder(),
      (builder, chunk) => builder..add(chunk),
    );
    final data = bytes.toBytes();

    // Create CID for the raw data
    final multihash = sha256Hash(data);
    final cid = CID.createV1(rawCode, multihash);

    // Single block
    final block = IPLDBlock(cid: cid, bytes: data);

    return UnixFSEncodeResult(
      rootCID: cid,
      blocks: [block],
    );
  }

  /// Encodes a chunked file with a root DAG-PB node.
  Future<UnixFSEncodeResult> _encodeChunkedFile(
    BlobLike file,
    int? fileSize,
  ) async {
    final blocks = <IPLDBlock>[];
    final leafCIDs = <CID>[];
    final leafSizes = <int>[];

    // Create chunker
    final chunker = FileChunker(chunkSize: options.chunkSize);

    // Encode each chunk as a raw block
    await for (final chunk in chunker.chunk(file)) {
      final multihash = sha256Hash(chunk);
      final cid = CID.createV1(rawCode, multihash);

      blocks.add(IPLDBlock(cid: cid, bytes: chunk));
      leafCIDs.add(cid);
      leafSizes.add(chunk.length);
    }

    // Special case: if we only got one chunk, return it as a raw block
    if (blocks.length == 1) {
      return UnixFSEncodeResult(
        rootCID: blocks[0].cid,
        blocks: blocks,
      );
    }

    // Calculate actual file size if not provided
    final actualFileSize =
        fileSize ?? leafSizes.fold<int>(0, (sum, size) => sum + size);

    // Create UnixFS Data for the root node
    final unixfsData = UnixFSDataEncoder.encode(
      type: UnixFSDataType.file,
      filesize: actualFileSize,
      blocksizes: leafSizes,
    );

    // Create PBLinks for each leaf
    final pbLinks = <Uint8List>[];
    for (var i = 0; i < leafCIDs.length; i++) {
      final link = PBLinkEncoder.encode(
        hash: leafCIDs[i].bytes,
        tsize: leafSizes[i],
      );
      pbLinks.add(link);
    }

    // Create root PBNode
    final pbNode = PBNodeEncoder.encode(
      data: unixfsData,
      links: pbLinks,
    );

    // Create root CID
    final rootMultihash = sha256Hash(pbNode);
    final rootCID = CID.createV1(dagPbCode, rootMultihash);

    // Add root block
    blocks.add(IPLDBlock(cid: rootCID, bytes: pbNode));

    return UnixFSEncodeResult(
      rootCID: rootCID,
      blocks: blocks,
    );
  }
}

