import 'dart:typed_data';

import '../multiformats/cid.dart';
import '../multiformats/varint.dart' as varint;
import 'car_types.dart';

/// Encodes IPLD blocks into a CAR (Content Addressable aRchive) file.
///
/// CAR format (v1):
/// ```
/// [Header length (varint)] [Header (CBOR)] [Block 1] [Block 2] ...
/// ```
///
/// Each block:
/// ```
/// [Block length (varint)] [CID bytes] [Block data]
/// ```
class CAREncoder {
  /// Encodes a list of blocks into a CAR file.
  ///
  /// The [roots] parameter specifies the root CIDs.
  /// The [blocks] parameter contains all blocks to include.
  ///
  /// Returns the complete CAR file as bytes.
  static Uint8List encode({
    required List<CID> roots,
    required List<CARBlock> blocks,
  }) {
    final builder = BytesBuilder();

    // Encode header
    final header = CARHeader(version: CARVersion.v1, roots: roots);
    final headerBytes = _encodeHeader(header);
    final headerLength = varint.encode(headerBytes.length);

    builder.add(headerLength);
    builder.add(headerBytes);

    // Encode blocks
    for (final block in blocks) {
      final blockBytes = _encodeBlock(block);
      builder.add(blockBytes);
    }

    return builder.toBytes();
  }

  /// Encodes a CAR header to CBOR format.
  static Uint8List _encodeHeader(CARHeader header) {
    // CBOR encoding for { version: 1, roots: [CID, ...] }
    final builder = BytesBuilder();

    // Map with 2 keys
    builder.addByte(0xA2); // CBOR major type 5 (map), additional info 2

    // Key: "version" (7 bytes)
    builder.addByte(0x67); // CBOR text string, length 7
    builder.add('version'.codeUnits);

    // Value: 1 (positive integer)
    builder.addByte(0x01); // CBOR major type 0, value 1

    // Key: "roots" (5 bytes)
    builder.addByte(0x65); // CBOR text string, length 5
    builder.add('roots'.codeUnits);

    // Value: array of CIDs
    final rootCount = header.roots.length;
    if (rootCount < 24) {
      builder.addByte(0x80 | rootCount); // CBOR array, length < 24
    } else if (rootCount < 256) {
      builder.addByte(0x98); // CBOR array, 1-byte length
      builder.addByte(rootCount);
    } else {
      builder.addByte(0x99); // CBOR array, 2-byte length
      builder.addByte((rootCount >> 8) & 0xFF);
      builder.addByte(rootCount & 0xFF);
    }

    // Encode each CID as CBOR bytes
    for (final cid in header.roots) {
      final cidBytes = cid.bytes;
      final length = cidBytes.length;

      if (length < 24) {
        builder.addByte(0x40 | length); // CBOR byte string, length < 24
      } else if (length < 256) {
        builder.addByte(0x58); // CBOR byte string, 1-byte length
        builder.addByte(length);
      } else {
        builder.addByte(0x59); // CBOR byte string, 2-byte length
        builder.addByte((length >> 8) & 0xFF);
        builder.addByte(length & 0xFF);
      }

      builder.add(cidBytes);
    }

    return builder.toBytes();
  }

  /// Encodes a single CAR block.
  static Uint8List _encodeBlock(CARBlock block) {
    final cidBytes = block.cid.bytes;
    final dataBytes = block.bytes;

    // Block = CID bytes + data bytes
    final blockLength = cidBytes.length + dataBytes.length;
    final lengthVarint = varint.encode(blockLength);

    final builder = BytesBuilder();
    builder.add(lengthVarint);
    builder.add(cidBytes);
    builder.add(dataBytes);

    return builder.toBytes();
  }

  /// Calculates the size of a CAR file without encoding it.
  static int calculateSize({
    required List<CID> roots,
    required List<CARBlock> blocks,
  }) {
    // Header
    final header = CARHeader(version: CARVersion.v1, roots: roots);
    final headerBytes = _encodeHeader(header);
    final headerLengthSize = varint.encodingLength(headerBytes.length);

    var totalSize = headerLengthSize + headerBytes.length;

    // Blocks
    for (final block in blocks) {
      final blockSize = block.cid.bytes.length + block.bytes.length;
      totalSize += varint.encodingLength(blockSize) + blockSize;
    }

    return totalSize;
  }
}

