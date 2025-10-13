/// CAR (Content Addressable aRchive) reader
/// 
/// Based on @ipld/car/src/buffer-decoder.js
/// This is a clean implementation following the reference client
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Decode CAR bytes into header and blocks
/// 
/// Reference: @ipld/car/src/buffer-decoder.js:fromBytes()
({CARHeader header, List<CARBlock> blocks}) readCar(Uint8List bytes) {
  final reader = _BytesReader(bytes);
  
  // Read header
  final header = _readHeader(reader);
  
  // Read all blocks
  final blocks = <CARBlock>[];
  while (reader.hasMore) {
    try {
      final block = _readBlock(reader);
      blocks.add(block);
    } catch (e) {
      // End of blocks or error
      break;
    }
  }
  
  return (header: header, blocks: blocks);
}

/// Read CAR header
/// 
/// Reference: @ipld/car/src/buffer-decoder.js:readHeader()
CARHeader _readHeader(_BytesReader reader) {
  // Read header length (varint)
  final headerLen = reader.readVarint();
  
  if (headerLen == 0) {
    throw FormatException('Invalid CAR header (zero length)');
  }
  
  // Read header bytes
  final headerBytes = reader.read(headerLen);
  
  // Decode DAG-CBOR header
  final decoded = _decodeDagCbor(headerBytes);
  
  // Extract version
  final version = decoded['version'];
  if (version != 1) {
    throw FormatException('Invalid CAR version: $version');
  }
  
  // Extract roots
  final rootsList = decoded['roots'];
  if (rootsList is! List) {
    throw FormatException('Invalid CAR header: roots must be an array');
  }
  
  final roots = <CID>[];
  for (final root in rootsList) {
    if (root is CID) {
      roots.add(root);
    } else if (root is Uint8List) {
      // Handle CID encoded as bytes (fallback for some encoders)
      roots.add(CID.decode(root));
    } else if (root is List<int>) {
      // Handle CID encoded as int list
      roots.add(CID.decode(Uint8List.fromList(root)));
    } else {
      throw FormatException('Invalid root: not a CID (got ${root.runtimeType})');
    }
  }
  
  return CARHeader(version: CARVersion.v1, roots: roots);
}

/// Read a single block from CAR
/// 
/// Reference: @ipld/car/src/buffer-decoder.js:readBlockHead()
CARBlock _readBlock(_BytesReader reader) {
  // Read block length (varint)
  final blockLen = reader.readVarint();
  
  if (blockLen == 0) {
    throw FormatException('Invalid CAR section (zero length)');
  }
  
  // Mark where block data starts (after the length varint)
  final blockDataStart = reader.pos;
  
  // Read CID
  final cid = _readCid(reader);
  
  // Calculate how many bytes the CID took
  final cidLen = reader.pos - blockDataStart;
  
  // Calculate data length
  final dataLen = blockLen - cidLen;
  
  // Read block data
  final data = reader.read(dataLen);
  
  return CARBlock(cid: cid, bytes: data);
}

/// Read CID from reader
/// 
/// Reference: @ipld/car/src/buffer-decoder.js:readCid()
CID _readCid(_BytesReader reader) {
  // Peek at first 2 bytes
  final first = reader.peek(2);
  
  // Check for CIDv0 (0x12 0x20 = sha256 with 32 bytes)
  if (first[0] == 0x12 && first[1] == 0x20) {
    // CIDv0: 34 bytes total
    final bytes = reader.read(34);
    return CID.decode(bytes);
  }
  
  // Read CIDv1 - we need to read varints to know total length
  final cidStart = reader.pos;
  
  final version = reader.readVarint();
  if (version != 1) {
    throw FormatException('Unexpected CID version: $version');
  }
  
  final codec = reader.readVarint();
  final hashCode = reader.readVarint();
  final hashLen = reader.readVarint();
  
  // Read the hash digest
  reader.read(hashLen);
  
  // Now we know the total CID length
  final cidEnd = reader.pos;
  final cidTotalLen = cidEnd - cidStart;
  
  // Go back and read all CID bytes
  reader.seek(cidStart);
  final cidBytes = reader.read(cidTotalLen);
  
  return CID.decode(cidBytes);
}

/// Decode DAG-CBOR bytes
/// 
/// Simplified decoder for CAR headers only
/// Only supports the subset needed for CAR headers: maps, arrays, ints, strings, and CIDs
Map<String, dynamic> _decodeDagCbor(Uint8List bytes) {
  final reader = _CborReader(bytes);
  final result = reader.readValue();
  
  if (result is! Map<String, dynamic>) {
    throw FormatException('Expected map at root');
  }
  
  return result;
}

/// Simple CBOR reader for DAG-CBOR
class _CborReader {
  _CborReader(this.bytes) : _offset = 0;
  
  final Uint8List bytes;
  int _offset;
  
  dynamic readValue() {
    final byte = bytes[_offset++];
    final majorType = byte >> 5;
    final additional = byte & 0x1F;
    
    switch (majorType) {
      case 0: // Unsigned int
        return _readInt(additional);
      case 2: // Byte string
        final len = _readInt(additional);
        final data = bytes.sublist(_offset, _offset + len);
        _offset += len;
        return data;
      case 3: // Text string
        final len = _readInt(additional);
        final data = bytes.sublist(_offset, _offset + len);
        _offset += len;
        return utf8.decode(data);
      case 4: // Array
        final len = _readInt(additional);
        final list = <dynamic>[];
        for (int i = 0; i < len; i++) {
          list.add(readValue());
        }
        return list;
      case 5: // Map
        final len = _readInt(additional);
        final map = <String, dynamic>{};
        for (int i = 0; i < len; i++) {
          final key = readValue();
          final value = readValue();
          if (key is! String) {
            throw FormatException('Map key must be string');
          }
          map[key] = value;
        }
        return map;
      case 6: // Tag
        final tagNum = _readInt(additional);
        if (tagNum == 42) {
          // CID tag - next value should be a byte string
          // Read the byte string directly
          final nextByte = bytes[_offset++];
          final nextMajor = nextByte >> 5;
          final nextAdditional = nextByte & 0x1F;
          
          if (nextMajor != 2) {
            throw FormatException('CID tag must be followed by byte string');
          }
          
          final len = _readInt(nextAdditional);
          var cidBytes = bytes.sublist(_offset, _offset + len);
          _offset += len;
          
          // DAG-CBOR CIDs have a 0x00 prefix byte for CIDv1
          // Skip it if present
          if (cidBytes.isNotEmpty && cidBytes[0] == 0x00) {
            cidBytes = cidBytes.sublist(1);
          }
          
          return CID.decode(cidBytes);
        }
        // For other tags, just read the value
        return readValue();
      default:
        throw FormatException('Unsupported CBOR major type: $majorType');
    }
  }
  
  int _readInt(int additional) {
    if (additional < 24) {
      return additional;
    } else if (additional == 24) {
      return bytes[_offset++];
    } else if (additional == 25) {
      final val = (bytes[_offset] << 8) | bytes[_offset + 1];
      _offset += 2;
      return val;
    } else if (additional == 26) {
      final val = (bytes[_offset] << 24) | 
                  (bytes[_offset + 1] << 16) |
                  (bytes[_offset + 2] << 8) |
                  bytes[_offset + 3];
      _offset += 4;
      return val;
    }
    throw FormatException('Unsupported int encoding');
  }
}

/// Bytes reader for CAR parsing
class _BytesReader {
  _BytesReader(this.bytes) : _pos = 0;
  
  final Uint8List bytes;
  int _pos;
  
  int get pos => _pos;
  bool get hasMore => _pos < bytes.length;
  
  /// Peek at bytes without advancing position
  Uint8List peek(int length) {
    if (_pos + length > bytes.length) {
      throw RangeError('Not enough data');
    }
    return bytes.sublist(_pos, _pos + length);
  }
  
  /// Read bytes and advance position
  Uint8List read(int length) {
    if (_pos + length > bytes.length) {
      throw RangeError('Unexpected end of data');
    }
    final result = bytes.sublist(_pos, _pos + length);
    _pos += length;
    return result;
  }
  
  /// Skip bytes
  void skip(int length) {
    _pos += length;
  }
  
  /// Seek to position
  void seek(int position) {
    _pos = position;
  }
  
  /// Read varint
  int readVarint() {
    final (value, bytesRead) = varint.decode(bytes, _pos);
    _pos += bytesRead;
    return value;
  }
}

