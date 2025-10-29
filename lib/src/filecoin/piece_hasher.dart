/// Filecoin Piece CID hasher
///
/// Implements the fr32-sha2-256-trunc254-padded-binary-tree multihash algorithm
/// used to compute piece CIDs for Filecoin storage deals.
///
/// Based on FRC-0058: https://github.com/filecoin-project/FIPs/blob/master/FRCs/frc-0058.md
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'fr32_padding.dart';
import 'fr32_constants.dart';

/// Multihash code for fr32-sha2-256-trunc254-padded-binary-tree
const int pieceHasherCode = 0x1011;

/// Computes piece CID from payload bytes
///
/// This is the main entry point for piece CID calculation.
/// It performs FR32 padding and builds a Merkle tree to compute
/// the piece commitment (CommP).
CID computePieceCid(Uint8List payload) {
  final hasher = PieceHasher();
  hasher.write(payload);
  final digest = hasher.digest();

  // Create CID with RAW codec and piece hasher multihash
  return CID.createV1(0x55, digest); // 0x55 = RAW codec
}

/// Piece hasher implementing the FR32 Merkle tree algorithm
class PieceHasher {
  /// Number of bytes written
  BigInt _bytesWritten = BigInt.zero;

  /// Buffer for accumulating bytes until we have a full quad
  final Uint8List _buffer = Uint8List(inBytesPerQuad);

  /// Current offset in buffer
  int _offset = 0;

  /// Merkle tree layers
  /// layers[0] = leaves, layers[1] = next level, etc.
  final List<List<Uint8List>> _layers = [[]];

  /// Write bytes into the hasher
  void write(Uint8List bytes) {
    final length = bytes.length;
    if (length == 0) return;

    // If buffer + new bytes < quad size, just accumulate
    if (_offset + length < _buffer.length) {
      _buffer.setRange(_offset, _offset + length, bytes);
      _offset += length;
      _bytesWritten += BigInt.from(length);
      return;
    }

    // Otherwise, fill buffer and process quads
    final bytesRequired = _buffer.length - _offset;

    // Fill the buffer to complete a quad
    _buffer.setRange(_offset, _buffer.length, bytes, 0);

    // Pad and split into leaves
    final paddedQuad = pad(_buffer);
    _addLeaves(_splitIntoLeaves(paddedQuad));

    // Process remaining bytes in quad-sized chunks
    int readOffset = bytesRequired;
    while (readOffset + inBytesPerQuad <= length) {
      final quad = bytes.sublist(readOffset, readOffset + inBytesPerQuad);
      final paddedChunk = pad(quad);
      _addLeaves(_splitIntoLeaves(paddedChunk));
      readOffset += inBytesPerQuad;
    }

    // Copy remaining bytes to buffer
    final remaining = length - readOffset;
    if (remaining > 0) {
      _buffer.setRange(0, remaining, bytes, readOffset);
    }
    _offset = remaining;

    _bytesWritten += BigInt.from(length);

    // Prune tree after adding leaves
    _pruneLayers();
  }

  /// Compute the final piece digest
  MultihashDigest digest() {
    // Make a copy of layers to avoid mutation
    final layersCopy = _layers.map((layer) => List<Uint8List>.from(layer)).toList();

    // If we have bytes in buffer, pad and add them as leaves
    if (_offset > 0 || _bytesWritten == BigInt.zero) {
      // Fill rest of buffer with zeros
      _buffer.fillRange(_offset, _buffer.length, 0);
      final paddedBuffer = pad(_buffer);
      final leaves = _splitIntoLeaves(paddedBuffer);
      layersCopy[0].addAll(leaves);
    }

    // Build complete tree by flushing all layers
    final tree = _buildTree(layersCopy);

    // Get root from top layer
    final height = tree.length - 1;
    final root = tree[height][0];

    // Calculate padding amount
    final padding = _calculatePadding(_bytesWritten);

    // Encode as multihash:
    // [varint code][varint size][varint padding][height byte][32-byte root]
    final digest = BytesBuilder();

    // Encode padding as varint
    _writeVarint(digest, padding);

    // Write height as single byte
    digest.addByte(height);

    // Write 32-byte root
    digest.add(root);

    final digestBytes = digest.toBytes();

    // Encode multihash: [code][size][digest]
    final output = BytesBuilder();
    _writeVarint(output, pieceHasherCode);
    _writeVarint(output, digestBytes.length);
    output.add(digestBytes);
    final multihashBytes = output.toBytes();

    // Create multihash digest
    return MultihashDigest(
      code: pieceHasherCode,
      size: digestBytes.length,
      digest: digestBytes,
      bytes: multihashBytes,
    );
  }

  /// Split FR32-padded data into 32-byte leaves
  ///
  /// CRITICAL: Unlike traditional Merkle trees, Filecoin piece trees
  /// do NOT hash the leaves. The raw 32-byte chunks ARE the leaves.
  List<Uint8List> _splitIntoLeaves(Uint8List paddedData) {
    final leaves = <Uint8List>[];
    for (int i = 0; i < paddedData.length; i += 32) {
      final end = (i + 32 <= paddedData.length) ? i + 32 : paddedData.length;
      final chunk = paddedData.sublist(i, end);

      // Pad chunk to 32 bytes if needed (but don't hash it!)
      final leaf = Uint8List(32);
      leaf.setRange(0, chunk.length, chunk);

      // Add raw chunk as leaf (NO HASHING)
      leaves.add(leaf);
    }
    return leaves;
  }

  /// Add leaves to layer 0 and prune
  void _addLeaves(List<Uint8List> leaves) {
    _layers[0].addAll(leaves);
  }

  /// Prune layers by combining node pairs
  void _pruneLayers() {
    _flushLayers(false);
  }

  /// Build complete tree by combining all layers
  List<List<Uint8List>> _buildTree(List<List<Uint8List>> layers) {
    return _flushLayers(true, inputLayers: layers);
  }

  /// Flush layers - combine node pairs into parent nodes
  List<List<Uint8List>> _flushLayers(bool build, {List<List<Uint8List>>? inputLayers}) {
    final layers = inputLayers ?? _layers;
    int level = 0;

    while (level < layers.length) {
      final layer = layers[level];

      // Pad odd layer with zero-comm if building
      if (build && layer.length % 2 == 1 && level + 1 < layers.length) {
        layer.add(_getZeroComm(level));
      }

      // Get or create next layer
      List<Uint8List> nextLayer;
      if (level + 1 < layers.length) {
        nextLayer = build ? List<Uint8List>.from(layers[level + 1]) : layers[level + 1];
      } else {
        nextLayer = [];
      }

      // Combine pairs of nodes
      int index = 0;
      while (index + 1 < layer.length) {
        final left = layer[index];
        final right = layer[index + 1];
        final parent = _computeNode(left, right);

        nextLayer.add(parent);

        // Remove processed nodes when not building
        if (!build) {
          layer[index] = Uint8List(0); // Clear for GC
          layer[index + 1] = Uint8List(0);
        }

        index += 2;
      }

      if (!build) {
        layer.removeRange(0, index);
      }

      if (nextLayer.isNotEmpty) {
        if (level + 1 >= layers.length) {
          layers.add(nextLayer);
        } else {
          layers[level + 1] = nextLayer;
        }
      }

      level++;
    }

    return layers;
  }

  /// Compute parent node from two child nodes
  ///
  /// CRITICAL: After hashing, the last byte is truncated by masking
  /// the top 2 bits to ensure it fits in a field element (254 bits max).
  Uint8List _computeNode(Uint8List left, Uint8List right) {
    final combined = Uint8List(64);
    combined.setRange(0, 32, left);
    combined.setRange(32, 64, right);

    final hash = sha256.convert(combined);
    final result = Uint8List.fromList(hash.bytes);

    // Truncate: mask top 2 bits of last byte (254-bit max)
    result[31] &= 0x3F; // 0b00111111

    return result;
  }

  /// Get zero commitment for a given level
  /// These are pre-computed zero hashes for empty subtrees
  Uint8List _getZeroComm(int level) {
    // For now, return a zero-filled 32-byte array
    // In production, these should be pre-computed constants
    final zeros = Uint8List(32);
    return zeros;
  }

  /// Calculate zero-byte padding amount
  ///
  /// CRITICAL: This is the number of zero BYTES added to reach the quad size,
  /// NOT the number of FR32 padding bits!
  int _calculatePadding(BigInt unpaddedSize) {
    final zeroPaddedSize = toZeroPaddedSize(unpaddedSize.toInt());
    return zeroPaddedSize - unpaddedSize.toInt();
  }

  /// Write varint to bytes builder
  void _writeVarint(BytesBuilder builder, int value) {
    while (value >= 0x80) {
      builder.addByte((value & 0x7F) | 0x80);
      value >>= 7;
    }
    builder.addByte(value & 0x7F);
  }
}
