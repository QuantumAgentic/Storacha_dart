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
  /// For small files that fit in a single chunk, returns a single RAW block.
  /// For larger files, creates a DAG-PB root with links to raw chunks.
  /// This matches the JS client behavior for Storacha compatibility.
  ///
  /// Returns a [UnixFSEncodeResult] containing the root CID and all blocks.
  Future<UnixFSEncodeResult> encodeFile(BlobLike file) async {
    final fileSize = file.size;
    return _encodeChunkedFile(file, fileSize);
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
      print('🐛 [UnixFS] Got chunk: ${chunk.length} bytes');
      final multihash = sha256Hash(chunk);
      final cid = CID.createV1(rawCode, multihash);

      blocks.add(IPLDBlock(cid: cid, bytes: chunk));
      leafCIDs.add(cid);
      leafSizes.add(chunk.length);
    }

    print('🐛 [UnixFS] Total chunks: ${leafCIDs.length}');
    print('🐛 [UnixFS] Checking if leafCIDs.length == 1: ${leafCIDs.length == 1}');

    // CRITICAL FIX: For single-block files, return RAW CID (not DAG-PB wrapper)
    // This matches JS client behavior and enables instant IPFS gateway retrieval
    if (leafCIDs.length == 1) {
      print('🐛 [UnixFS] ✅ Returning single RAW block without DAG-PB wrapper');
      return UnixFSEncodeResult(
        rootCID: leafCIDs[0],
        blocks: blocks,
      );
    }

    print('🐛 [UnixFS] Creating DAG-PB wrapper for ${leafCIDs.length} chunks');

    // For multi-block files, create DAG-PB root node
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

