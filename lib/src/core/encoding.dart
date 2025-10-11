/// Encoding utilities for UCAN and HTTP transport
library;

import 'dart:convert';
import 'dart:typed_data';

/// Base64URL encoding (RFC 4648)
///
/// Used for JWT and UCAN encoding.
/// Differs from standard base64 by using URL-safe characters and no padding.
class Base64Url {
  /// Encode bytes to base64url string
  static String encode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decode base64url string to bytes
  static Uint8List decode(String str) {
    // Add padding if needed
    var padded = str;
    final mod = str.length % 4;
    if (mod > 0) {
      padded += '=' * (4 - mod);
    }
    return base64Url.decode(padded);
  }

  /// Encode UTF-8 string to base64url
  static String encodeString(String str) => encode(utf8.encode(str));

  /// Decode base64url to UTF-8 string
  static String decodeString(String str) => utf8.decode(decode(str));
}

/// Simple CBOR encoder for UCAN invocations
///
/// This is a minimal CBOR implementation supporting only the types needed
/// for UCAN encoding. For full CBOR support, use a dedicated package.
class SimpleCborEncoder {
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
    } else if (value is String) {
      _encodeString(value);
    } else if (value is Uint8List) {
      // Explicit Uint8List is bytes
      _encodeBytes(value);
    } else if (value is List) {
      // Generic List is array
      _encodeArray(value);
    } else if (value is Map) {
      _encodeMap(value);
    } else {
      throw ArgumentError('Unsupported CBOR type: ${value.runtimeType}');
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
      } else {
        throw ArgumentError('Negative integers < -256 not yet supported');
      }
    }
  }

  void _encodeString(String value) {
    final bytes = utf8.encode(value);
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

  void _encodeBytes(List<int> value) {
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

    for (final entry in value.entries) {
      encode(entry.key);
      encode(entry.value);
    }
  }
}

/// Encode value to CBOR bytes
Uint8List encodeCbor(dynamic value) {
  final encoder = SimpleCborEncoder();
  encoder.encode(value);
  return encoder.toBytes();
}

