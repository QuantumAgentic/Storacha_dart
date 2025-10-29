import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

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
///
/// The [roots] parameter specifies the root CIDs.
/// The [blocks] parameter contains all blocks to include.
///
/// Returns the complete CAR file as bytes.
Uint8List encodeCar({
  required List<CID> roots,
  required List<CARBlock> blocks,
}) {
  final result = encodeCarWithPositions(roots: roots, blocks: blocks);
  return result.bytes;
}

/// Encodes IPLD blocks into a CAR file and returns both the bytes and block positions.
///
/// This is useful for creating ShardedDAGIndex, which needs to know the exact
/// position of each block within the CAR file.
///
/// Returns [EncodedCAR] containing:
/// - bytes: The complete CAR file
/// - blockPositions: Map of CID → (offset, length) for each block
EncodedCAR encodeCarWithPositions({
  required List<CID> roots,
  required List<CARBlock> blocks,
}) {
  final builder = BytesBuilder();
  final blockPositions = <CID, (int, int)>{};

  // Encode header
  final header = CARHeader(version: CARVersion.v1, roots: roots);
  final headerBytes = _encodeCarHeader(header);
  final headerLength = varint.encode(headerBytes.length);

  builder
    ..add(headerLength)
    ..add(headerBytes);

  var currentOffset = headerLength.length + headerBytes.length;

  // Encode blocks and track their positions
  for (final block in blocks) {
    final cidBytes = block.cid.bytes;
    final dataBytes = block.bytes;
    final blockLength = cidBytes.length + dataBytes.length;
    final lengthVarint = varint.encode(blockLength);

    // Calculate position: [offset_to_data_start, data_length]
    // This matches the JS client's ShardingStream behavior
    final blockHeaderLength = lengthVarint.length + cidBytes.length;
    final dataOffset = currentOffset + blockHeaderLength;
    
    // Store position: offset points to the start of the DATA (not varint)
    // and length is just the data length (not including varint+CID)
    blockPositions[block.cid] = (dataOffset, dataBytes.length);

    builder
      ..add(lengthVarint)
      ..add(cidBytes)
      ..add(dataBytes);

    currentOffset += lengthVarint.length + blockLength;
  }

  return EncodedCAR(
    bytes: builder.toBytes(),
    blockPositions: blockPositions,
  );
}

/// Encodes a CAR header to CBOR format.
Uint8List _encodeCarHeader(CARHeader header) {
    // CBOR encoding for { roots: [CID, ...], version: 1 }
    // IMPORTANT: Keys must be in alphabetical order for canonical CBOR
    final builder = BytesBuilder()
      ..addByte(0xA2) // CBOR major type 5 (map), additional info 2
      ..addByte(0x65) // CBOR text string, length 5
      ..add('roots'.codeUnits);

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

    // Encode each CID as CBOR tag 42 + bytes (with 0x00 prefix)
    for (final cid in header.roots) {
      // Add CBOR tag 42 for CID
      builder
        ..addByte(0xD8) // CBOR tag (major type 6, additional info 24)
        ..addByte(0x2A); // Tag number 42

      // CID bytes with 0x00 multibase prefix
      final cidBytes = cid.bytes;
      final length = cidBytes.length + 1; // +1 for the 0x00 prefix

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

      builder
        ..addByte(0x00) // Multibase identity prefix
        ..add(cidBytes);
    }

    // Add version after roots (alphabetical order: roots < version)
    builder
      ..addByte(0x67) // CBOR text string, length 7
      ..add('version'.codeUnits)
      ..addByte(0x01); // CBOR major type 0, value 1

    return builder.toBytes();
  }

/// Calculates the size of a CAR file without encoding it.
int calculateCarSize({
  required List<CID> roots,
  required List<CARBlock> blocks,
}) {
  // Header
  final header = CARHeader(version: CARVersion.v1, roots: roots);
  final headerBytes = _encodeCarHeader(header);
  final headerLengthSize = varint.encodingLength(headerBytes.length);

  var totalSize = headerLengthSize + headerBytes.length;

  // Blocks
  for (final block in blocks) {
    final blockSize = block.cid.bytes.length + block.bytes.length;
    totalSize += varint.encodingLength(blockSize) + blockSize;
  }

  return totalSize;
}

