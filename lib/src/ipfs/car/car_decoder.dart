import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Result of decoding a CAR file
class CARDecodeResult {
  const CARDecodeResult({
    required this.header,
    required this.blocks,
  });

  /// The CAR header
  final CARHeader header;

  /// All blocks in the CAR file
  final List<CARBlock> blocks;
}

/// Decodes a CAR (Content Addressable aRchive) file.
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
/// Returns decoded header and blocks.
/// Throws [FormatException] if the CAR data is invalid.
CARDecodeResult decodeCar(Uint8List bytes) {
  final reader = _ByteReader(bytes);

  // Decode header length
  final headerLength = reader.readVarint();

  // Decode header
  final headerBytes = reader.readBytes(headerLength);
  final header = _decodeCarHeader(headerBytes);

  // Decode blocks
  final blocks = <CARBlock>[];
  while (!reader.isEof) {
    final block = _decodeCarBlock(reader);
    blocks.add(block);
  }

  return CARDecodeResult(header: header, blocks: blocks);
}

/// Decodes a CAR header from CBOR format.
CARHeader _decodeCarHeader(Uint8List bytes) {
  try {
    final reader = _ByteReader(bytes);

    // Expect CBOR map with 2 entries
    final mapHeader = reader.readByte();
    if (mapHeader != 0xA2) {
      throw FormatException('Invalid CAR header: expected map with 2 entries');
    }

    // Read "version" key
    final versionKeyLength = reader.readByte();
    if (versionKeyLength != 0x67) {
      throw FormatException('Invalid CAR header: expected "version" key');
    }
    final versionKey = utf8.decode(reader.readBytes(7));
    if (versionKey != 'version') {
      throw FormatException('Invalid CAR header: expected "version" key');
    }

    // Read version value
    final versionValue = reader.readByte();
    if (versionValue != 0x01) {
      throw FormatException('Invalid CAR version: expected 1');
    }

    // Read "roots" key
    final rootsKeyLength = reader.readByte();
    if (rootsKeyLength != 0x65) {
      throw FormatException('Invalid CAR header: expected "roots" key');
    }
    final rootsKey = utf8.decode(reader.readBytes(5));
    if (rootsKey != 'roots') {
      throw FormatException('Invalid CAR header: expected "roots" key');
    }

    // Read roots array
    final arrayHeader = reader.readByte();
    int rootCount;

    if ((arrayHeader & 0xE0) == 0x80) {
      // Array with length < 24
      rootCount = arrayHeader & 0x1F;
    } else if (arrayHeader == 0x98) {
      // Array with 1-byte length
      rootCount = reader.readByte();
    } else if (arrayHeader == 0x99) {
      // Array with 2-byte length
      final highByte = reader.readByte();
      final lowByte = reader.readByte();
      rootCount = (highByte << 8) | lowByte;
    } else {
      throw FormatException('Invalid CAR header: unsupported array format');
    }

    // Read CIDs
    final roots = <CID>[];
    for (var i = 0; i < rootCount; i++) {
      final byteStringHeader = reader.readByte();
      int cidLength;

      if (byteStringHeader >= 0x40 && byteStringHeader <= 0x57) {
        // Byte string with length 0-23 (embedded in header byte)
        cidLength = byteStringHeader & 0x1F;
      } else if (byteStringHeader == 0x58) {
        // Byte string with 1-byte length
        cidLength = reader.readByte();
      } else if (byteStringHeader == 0x59) {
        // Byte string with 2-byte length
        final highByte = reader.readByte();
        final lowByte = reader.readByte();
        cidLength = (highByte << 8) | lowByte;
      } else {
        throw FormatException('Invalid CAR header: unsupported byte string format');
      }

      final cidBytes = reader.readBytes(cidLength);
      final cid = CID.decode(cidBytes);
      roots.add(cid);
    }

    return CARHeader(version: CARVersion.v1, roots: roots);
  } catch (e) {
    throw FormatException('Failed to decode CAR header: $e');
  }
}

/// Decodes a single CAR block.
CARBlock _decodeCarBlock(_ByteReader reader) {
  // Read block length
  final blockLength = reader.readVarint();

  // Read block data (CID + data)
  final blockData = reader.readBytes(blockLength);
  final blockReader = _ByteReader(blockData);

  // Parse CID from block data
  // CID starts with version byte
  final cidVersion = blockReader.readByte();

  if (cidVersion == 0x12) {
    // CIDv0 (starts with 0x12 0x20 for SHA-256)
    final hashFunction = 0x12;
    final digestLength = blockReader.readByte();
    if (digestLength != 0x20) {
      throw FormatException('Invalid CIDv0: expected 32-byte hash');
    }
    final digest = blockReader.readBytes(32);

    // Reconstruct CID bytes
    final cidBytes = Uint8List(34);
    cidBytes[0] = hashFunction;
    cidBytes[1] = digestLength;
    cidBytes.setRange(2, 34, digest);

    final cid = CID.decode(cidBytes);
    final data = blockReader.readRemaining();

    return CARBlock(cid: cid, bytes: data);
  } else if (cidVersion == 0x01) {
    // CIDv1
    final codec = blockReader.readVarint();
    final hashFunction = blockReader.readVarint();
    final digestLength = blockReader.readVarint();
    final digest = blockReader.readBytes(digestLength);

    // Reconstruct CID bytes
    final cidBytes = BytesBuilder()
      ..addByte(cidVersion)
      ..add(varint.encode(codec))
      ..add(varint.encode(hashFunction))
      ..add(varint.encode(digestLength))
      ..add(digest);

    final cid = CID.decode(cidBytes.toBytes());
    final data = blockReader.readRemaining();

    return CARBlock(cid: cid, bytes: data);
  } else {
    throw FormatException('Unsupported CID version: $cidVersion');
  }
}

/// Helper class for reading bytes sequentially
class _ByteReader {
  _ByteReader(this.bytes) : _offset = 0;

  final Uint8List bytes;
  int _offset;

  /// Check if we've reached the end of the data
  bool get isEof => _offset >= bytes.length;

  /// Read a single byte
  int readByte() {
    if (_offset >= bytes.length) {
      throw RangeError('Unexpected end of CAR data');
    }
    return bytes[_offset++];
  }

  /// Read multiple bytes
  Uint8List readBytes(int count) {
    if (_offset + count > bytes.length) {
      throw RangeError('Unexpected end of CAR data');
    }
    final result = bytes.sublist(_offset, _offset + count);
    _offset += count;
    return result;
  }

  /// Read all remaining bytes
  Uint8List readRemaining() {
    final result = bytes.sublist(_offset);
    _offset = bytes.length;
    return result;
  }

  /// Read a varint (variable-length integer)
  int readVarint() {
    var result = 0;
    var shift = 0;

    while (true) {
      if (_offset >= bytes.length) {
        throw FormatException('Incomplete varint at end of CAR data');
      }

      final byte = bytes[_offset++];
      result |= (byte & 0x7F) << shift;

      if ((byte & 0x80) == 0) {
        return result;
      }

      shift += 7;

      if (shift > 63) {
        throw FormatException('Varint too long');
      }
    }
  }
}

