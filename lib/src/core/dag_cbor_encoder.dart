/// DAG-CBOR encoder with support for CIDs and DIDs
/// 
/// This implements the DAG-CBOR format used by UCANTO/Storacha for IPLD data structures.
/// Reference: @ipld/dag-cbor
library;

import 'dart:typed_data';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/did_decoder.dart' show parseDid;

/// DAG-CBOR multicodec code
const dagCborCode = 0x71;

/// CBOR tag for CID (tag 42)
const cidTag = 42;

/// Encode a value to DAG-CBOR bytes
Uint8List encodeDagCbor(dynamic value) {
  final encoder = DagCborEncoder();
  encoder.encode(value);
  return encoder.toBytes();
}

/// DAG-CBOR encoder
class DagCborEncoder {
  final BytesBuilder _builder = BytesBuilder();

  /// Get the encoded bytes
  Uint8List toBytes() => _builder.toBytes();

  /// Encode any supported value
  void encode(dynamic value) {
    if (value == null) {
      _encodeNull();
    } else if (value is bool) {
      _encodeBool(value);
    } else if (value is int) {
      _encodeInt(value);
    } else if (value is double) {
      _encodeFloat(value);
    } else if (value is String) {
      _encodeString(value);
    } else if (value is CID) {
      _encodeCID(value);
    } else if (value is Uint8List) {
      _encodeBytes(value);
    } else if (value is List<int>) {
      _encodeBytes(Uint8List.fromList(value));
    } else if (value is List) {
      _encodeArray(value);
    } else if (value is Map) {
      _encodeMap(value);
    } else {
      throw ArgumentError('Unsupported DAG-CBOR type: ${value.runtimeType}');
    }
  }

  void _encodeNull() {
    _builder.addByte(0xF6);
  }

  void _encodeBool(bool value) {
    _builder.addByte(value ? 0xF5 : 0xF4);
  }

  void _encodeInt(int value) {
    if (value >= 0) {
      // Positive integer
      if (value < 24) {
        _builder.addByte(value);
      } else if (value < 256) {
        _builder.addByte(0x18);
        _builder.addByte(value);
      } else if (value < 65536) {
        _builder.addByte(0x19);
        _builder.addByte((value >> 8) & 0xFF);
        _builder.addByte(value & 0xFF);
      } else if (value < 4294967296) {
        _builder.addByte(0x1A);
        _builder.addByte((value >> 24) & 0xFF);
        _builder.addByte((value >> 16) & 0xFF);
        _builder.addByte((value >> 8) & 0xFF);
        _builder.addByte(value & 0xFF);
      } else {
        _builder.addByte(0x1B);
        for (var i = 7; i >= 0; i--) {
          _builder.addByte((value >> (i * 8)) & 0xFF);
        }
      }
    } else {
      // Negative integer
      final absValue = -1 - value;
      if (absValue < 24) {
        _builder.addByte(0x20 | absValue);
      } else if (absValue < 256) {
        _builder.addByte(0x38);
        _builder.addByte(absValue);
      } else if (absValue < 65536) {
        _builder.addByte(0x39);
        _builder.addByte((absValue >> 8) & 0xFF);
        _builder.addByte(absValue & 0xFF);
      } else {
        throw ArgumentError('Negative integers < -65536 not yet supported');
      }
    }
  }

  void _encodeFloat(double value) {
    // Encode as CBOR float64
    _builder.addByte(0xFB);
    final bytes = ByteData(8);
    bytes.setFloat64(0, value, Endian.big);
    _builder.add(bytes.buffer.asUint8List());
  }

  void _encodeString(String value) {
    final bytes = value.codeUnits;
    final length = bytes.length;

    if (length < 24) {
      _builder.addByte(0x60 | length);
    } else if (length < 256) {
      _builder.addByte(0x78);
      _builder.addByte(length);
    } else if (length < 65536) {
      _builder.addByte(0x79);
      _builder.addByte((length >> 8) & 0xFF);
      _builder.addByte(length & 0xFF);
    } else {
      throw ArgumentError('Strings longer than 64KB not yet supported');
    }

    _builder.add(bytes);
  }

  void _encodeBytes(Uint8List value) {
    final length = value.length;

    if (length < 24) {
      _builder.addByte(0x40 | length);
    } else if (length < 256) {
      _builder.addByte(0x58);
      _builder.addByte(length);
    } else if (length < 65536) {
      _builder.addByte(0x59);
      _builder.addByte((length >> 8) & 0xFF);
      _builder.addByte(length & 0xFF);
    } else {
      throw ArgumentError('Byte arrays longer than 64KB not yet supported');
    }

    _builder.add(value);
  }

  void _encodeArray(List<dynamic> value) {
    final length = value.length;

    if (length < 24) {
      _builder.addByte(0x80 | length);
    } else if (length < 256) {
      _builder.addByte(0x98);
      _builder.addByte(length);
    } else {
      throw ArgumentError('Arrays longer than 255 elements not yet supported');
    }

    for (final item in value) {
      encode(item);
    }
  }

  void _encodeMap(Map<dynamic, dynamic> value) {
    final length = value.length;

    if (length < 24) {
      _builder.addByte(0xA0 | length);
    } else if (length < 256) {
      _builder.addByte(0xB8);
      _builder.addByte(length);
    } else {
      throw ArgumentError('Maps longer than 255 entries not yet supported');
    }

    // Sort keys for deterministic encoding (DAG-CBOR requirement)
    final sortedEntries = value.entries.toList()
      ..sort((a, b) {
        final aBytes = _encodeKeyForSort(a.key);
        final bBytes = _encodeKeyForSort(b.key);
        for (var i = 0; i < aBytes.length && i < bBytes.length; i++) {
          if (aBytes[i] != bBytes[i]) {
            return aBytes[i].compareTo(bBytes[i]);
          }
        }
        return aBytes.length.compareTo(bBytes.length);
      });

    for (final entry in sortedEntries) {
      encode(entry.key);
      encode(entry.value);
    }
  }

  Uint8List _encodeKeyForSort(dynamic key) {
    final tempEncoder = DagCborEncoder();
    tempEncoder.encode(key);
    return tempEncoder.toBytes();
  }

  void _encodeCID(CID cid) {
    // CID is encoded as CBOR tag 42 with the CID bytes
    // Tag 42 = 0xD8 0x2A
    // The CID bytes must be prefixed with 0x00 for historical reasons
    // (matches @ipld/dag-cbor implementation)
    _builder.addByte(0xD8);
    _builder.addByte(0x2A);
    
    // Prefix CID bytes with 0x00
    final cidWithPrefix = Uint8List(cid.bytes.length + 1);
    cidWithPrefix[0] = 0x00;
    cidWithPrefix.setRange(1, cidWithPrefix.length, cid.bytes);
    
    // Encode the prefixed CID bytes as byte string
    _encodeBytes(cidWithPrefix);
  }
}

/// Helper to encode a DID string to bytes for DAG-CBOR
Uint8List encodeDIDForCBOR(String did) {
  return parseDid(did);
}

