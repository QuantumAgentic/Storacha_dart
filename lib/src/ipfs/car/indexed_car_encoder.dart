import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Encodes IPLD blocks into an Indexed CAR (Content Addressable aRchive) file.
///
/// An indexed CAR is a CAR file with a special index block appended at the end
/// that describes the structure of the CAR (slices, roots, offsets).
///
/// This follows the exact format used by the official JS client for Storacha
/// to ensure content hashes match exactly.
///
/// Format:
/// ```
/// [CAR Header][Block 1][Block 2]...[Index Block (CARv2 compatible)]
/// ```
class IndexedCarEncoder {
  /// Encodes blocks into an indexed CAR file.
  ///
  /// Returns both the CAR bytes and the root CID.
  static IndexedCarResult encode({
    required List<CID> roots,
    required List<CARBlock> blocks,
  }) {
    final builder = BytesBuilder();

    // Track slice information (CID → offset/length in CAR)
    final slices = <CID, SliceInfo>{};
    var currentOffset = 0;

    // 1. Encode CAR header
    final headerBytes = _encodeCarHeader(roots);
    final headerLengthVarint = varint.encode(headerBytes.length);
    builder
      ..add(headerLengthVarint)
      ..add(headerBytes);
    
    currentOffset += headerLengthVarint.length + headerBytes.length;

    // 2. Encode each block and track its position
    for (final block in blocks) {
      final cidBytes = block.cid.bytes;
      final dataBytes = block.bytes;
      final blockLength = cidBytes.length + dataBytes.length;
      final lengthVarint = varint.encode(blockLength);

      // Record slice info (offset points to CID start, length includes CID+data)
      slices[block.cid] = SliceInfo(
        offset: currentOffset,
        length: lengthVarint.length + blockLength,
      );

      builder
        ..add(lengthVarint)
        ..add(cidBytes)
        ..add(dataBytes);

      currentOffset += lengthVarint.length + blockLength;
    }

    // 3. Create and append index block (slices)
    final indexBlock = _createIndexBlock(roots, slices);
    builder.add(indexBlock);

    final carBytes = builder.toBytes();

    return IndexedCarResult(
      carBytes: carBytes,
      rootCID: roots.first,
      slices: slices,
    );
  }

  /// Encodes CAR header in canonical CBOR format.
  static Uint8List _encodeCarHeader(List<CID> roots) {
    // CBOR encoding for { roots: [CID, ...], version: 1 }
    // Keys MUST be alphabetically sorted for canonical encoding
    final builder = BytesBuilder()
      ..addByte(0xA2) // CBOR map with 2 items
      ..addByte(0x65) // Text string of length 5
      ..add('roots'.codeUnits);

    // Encode roots array
    final rootCount = roots.length;
    if (rootCount < 24) {
      builder.addByte(0x80 | rootCount); // Array length < 24
    } else if (rootCount < 256) {
      builder
        ..addByte(0x98) // Array with 1-byte length
        ..addByte(rootCount);
    } else {
      builder
        ..addByte(0x99) // Array with 2-byte length
        ..addByte((rootCount >> 8) & 0xFF)
        ..addByte(rootCount & 0xFF);
    }

    // Encode each root CID as CBOR tag 42
    for (final cid in roots) {
      builder
        ..addByte(0xD8) // CBOR tag
        ..addByte(0x2A); // Tag 42 (CID)

      final cidBytes = cid.bytes;
      final length = cidBytes.length + 1; // +1 for 0x00 prefix

      if (length < 24) {
        builder.addByte(0x40 | length);
      } else if (length < 256) {
        builder
          ..addByte(0x58)
          ..addByte(length);
      } else {
        builder
          ..addByte(0x59)
          ..addByte((length >> 8) & 0xFF)
          ..addByte(length & 0xFF);
      }

      builder
        ..addByte(0x00) // Multibase identity prefix
        ..add(cidBytes);
    }

    // Add version (alphabetically after roots)
    builder
      ..addByte(0x67) // Text string of length 7
      ..add('version'.codeUnits)
      ..addByte(0x01); // Integer 1

    return builder.toBytes();
  }

  /// Creates the index block (slices) for CARv2 compatibility.
  ///
  /// The index block is a CBOR-encoded map containing:
  /// - 'slices': Map of CID → [offset, length]
  /// - 'version': 1
  static Uint8List _createIndexBlock(
    List<CID> roots,
    Map<CID, SliceInfo> slices,
  ) {
    final builder = BytesBuilder();

    // CBOR map with 2 keys: slices, version
    builder.addByte(0xA2);

    // Key: "slices" (6 chars)
    builder
      ..addByte(0x66)
      ..add('slices'.codeUnits);

    // Value: Map of CID → [offset, length]
    final sliceCount = slices.length;
    if (sliceCount < 24) {
      builder.addByte(0xA0 | sliceCount);
    } else if (sliceCount < 256) {
      builder
        ..addByte(0xB8)
        ..addByte(sliceCount);
    } else {
      builder
        ..addByte(0xB9)
        ..addByte((sliceCount >> 8) & 0xFF)
        ..addByte(sliceCount & 0xFF);
    }

    // Encode each slice entry
    for (final entry in slices.entries) {
      final cid = entry.key;
      final info = entry.value;

      // Key: CID as CBOR tag 42 + bytes
      builder
        ..addByte(0xD8)
        ..addByte(0x2A);

      final cidBytes = cid.bytes;
      final cidLength = cidBytes.length + 1;

      if (cidLength < 24) {
        builder.addByte(0x40 | cidLength);
      } else if (cidLength < 256) {
        builder
          ..addByte(0x58)
          ..addByte(cidLength);
      } else {
        builder
          ..addByte(0x59)
          ..addByte((cidLength >> 8) & 0xFF)
          ..addByte(cidLength & 0xFF);
      }

      builder
        ..addByte(0x00)
        ..add(cidBytes);

      // Value: [offset, length] as CBOR array
      builder.addByte(0x82); // Array of 2 items

      // Encode offset as CBOR integer
      _encodeCborInt(builder, info.offset);

      // Encode length as CBOR integer
      _encodeCborInt(builder, info.length);
    }

    // Key: "version" (7 chars)
    builder
      ..addByte(0x67)
      ..add('version'.codeUnits);

    // Value: 1
    builder.addByte(0x01);

    return builder.toBytes();
  }

  /// Encodes an integer in CBOR format.
  static void _encodeCborInt(BytesBuilder builder, int value) {
    if (value < 24) {
      builder.addByte(value);
    } else if (value < 256) {
      builder
        ..addByte(0x18)
        ..addByte(value);
    } else if (value < 65536) {
      builder
        ..addByte(0x19)
        ..addByte((value >> 8) & 0xFF)
        ..addByte(value & 0xFF);
    } else if (value < 4294967296) {
      builder
        ..addByte(0x1A)
        ..addByte((value >> 24) & 0xFF)
        ..addByte((value >> 16) & 0xFF)
        ..addByte((value >> 8) & 0xFF)
        ..addByte(value & 0xFF);
    } else {
      // 64-bit
      builder
        ..addByte(0x1B)
        ..addByte((value >> 56) & 0xFF)
        ..addByte((value >> 48) & 0xFF)
        ..addByte((value >> 40) & 0xFF)
        ..addByte((value >> 32) & 0xFF)
        ..addByte((value >> 24) & 0xFF)
        ..addByte((value >> 16) & 0xFF)
        ..addByte((value >> 8) & 0xFF)
        ..addByte(value & 0xFF);
    }
  }
}

/// Information about a block's position in the CAR file.
class SliceInfo {
  const SliceInfo({
    required this.offset,
    required this.length,
  });

  final int offset;
  final int length;
}

/// Result of indexed CAR encoding.
class IndexedCarResult {
  const IndexedCarResult({
    required this.carBytes,
    required this.rootCID,
    required this.slices,
  });

  final Uint8List carBytes;
  final CID rootCID;
  final Map<CID, SliceInfo> slices;
}

