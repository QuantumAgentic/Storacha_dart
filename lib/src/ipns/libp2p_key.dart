/// Libp2p key encoding for IPNS names
///
/// Converts Ed25519 public keys to libp2p key format and CID v1 with base36 encoding.
/// This matches the format used by w3name and standard IPNS implementations.
///
/// Example:
/// ```dart
/// final publicKey = Uint8List(32); // Ed25519 public key bytes
/// final cid = Libp2pKey.publicKeyToCid(publicKey);
/// print(cid); // k51qzi5uqu5...
/// ```
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Libp2p key format utilities
class Libp2pKey {
  /// Ed25519 key type in Protobuf (libp2p format)
  static const int ed25519KeyType = 0x01;

  /// Libp2p key multicodec code
  static const int libp2pKeyCode = 0x72;

  /// Identity multihash code (no hashing)
  static const int identityCode = 0x00;

  /// Base36 alphabet (lowercase)
  static const String base36Alphabet =
      '0123456789abcdefghijklmnopqrstuvwxyz';

  /// CID v1 prefix
  static const int cidV1 = 0x01;

  /// Convert Ed25519 public key to CID v1 base36 string
  ///
  /// Process:
  /// 1. Wrap public key in Protobuf (Ed25519PublicKey)
  /// 2. Create identity multihash (no hashing, just wrap)
  /// 3. Create CID v1 with libp2p-key codec
  /// 4. Encode to base36
  ///
  /// Returns: k51qzi5uqu5... formatted string
  static String publicKeyToCid(Uint8List publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError('Ed25519 public key must be 32 bytes');
    }

    // 1. Wrap in Protobuf Ed25519PublicKey
    final protobufKey = _wrapProtobuf(publicKey);

    // 2. Create identity multihash (code=0x00, length=payload length, data=payload)
    final multihash = _createIdentityMultihash(protobufKey);

    // 3. Create CID v1: <version><codec><multihash>
    final cid = _createCidV1(multihash);

    // 4. Encode to base36 with 'k' prefix
    return 'k${_encodeBase36(cid)}';
  }

  /// Parse base36-encoded CID back to bytes
  static Uint8List cidToBytes(String cid) {
    if (!cid.startsWith('k')) {
      throw ArgumentError('CID must start with "k" (base36 prefix)');
    }

    return _decodeBase36(cid.substring(1));
  }

  /// Extract public key from CID
  static Uint8List publicKeyFromCid(String cid) {
    final bytes = cidToBytes(cid);

    // Parse CID: version(1) + codec(varint) + multihash
    int offset = 0;

    // Check version
    if (bytes[offset] != cidV1) {
      throw FormatException('Only CID v1 is supported');
    }
    offset++;

    // Read codec (varint)
    final (codec, codecLen) = _readVarint(bytes, offset);
    if (codec != libp2pKeyCode) {
      throw FormatException('Expected libp2p-key codec (0x72), got 0x${codec.toRadixString(16)}');
    }
    offset += codecLen;

    // Read multihash: code + length + data
    if (bytes[offset] != identityCode) {
      throw FormatException('Expected identity multihash');
    }
    offset++;

    final length = bytes[offset];
    offset++;

    final protobufKey = bytes.sublist(offset, offset + length);

    // Unwrap Protobuf
    return _unwrapProtobuf(protobufKey);
  }

  /// Wrap Ed25519 public key in Protobuf format
  ///
  /// Protobuf structure (libp2p PublicKey):
  /// - Field 1 (Type): varint with value 1 (Ed25519)
  /// - Field 2 (Data): length-delimited with key bytes
  static Uint8List _wrapProtobuf(Uint8List publicKey) {
    final buffer = BytesBuilder();

    // Field 1: Type = Ed25519 (varint 1)
    // Tag = (field_number << 3) | wire_type = (1 << 3) | 0 = 0x08
    buffer.addByte(0x08);
    buffer.addByte(ed25519KeyType); // Value = 0x01

    // Field 2: Data = public key bytes (length-delimited)
    // Tag = (2 << 3) | 2 = 0x12
    buffer.addByte(0x12);
    buffer.addByte(publicKey.length); // Length = 32 (0x20)
    buffer.add(publicKey); // Data

    return buffer.toBytes();
  }

  /// Unwrap Protobuf to get Ed25519 public key
  static Uint8List _unwrapProtobuf(Uint8List protobuf) {
    int offset = 0;

    // Read field 1 (Type)
    if (protobuf[offset] != 0x08) {
      throw FormatException('Invalid Protobuf: expected type field');
    }
    offset++;

    if (protobuf[offset] != ed25519KeyType) {
      throw FormatException('Expected Ed25519 key type (0x01), got 0x${protobuf[offset].toRadixString(16)}');
    }
    offset++;

    // Read field 2 (Data)
    if (protobuf[offset] != 0x12) {
      throw FormatException('Invalid Protobuf: expected data field');
    }
    offset++;

    final length = protobuf[offset];
    offset++;

    return protobuf.sublist(offset, offset + length);
  }

  /// Create identity multihash (no hashing, just wraps data)
  ///
  /// Format: <code><length><data>
  static Uint8List _createIdentityMultihash(Uint8List data) {
    final buffer = BytesBuilder();
    buffer.addByte(identityCode); // Code = 0x00
    buffer.addByte(data.length); // Length
    buffer.add(data); // Data
    return buffer.toBytes();
  }

  /// Create CID v1 from multihash
  ///
  /// Format: <version><codec><multihash>
  static Uint8List _createCidV1(Uint8List multihash) {
    final buffer = BytesBuilder();
    buffer.addByte(cidV1); // Version = 0x01

    // Codec as varint (libp2p-key = 0x72)
    _writeVarint(buffer, libp2pKeyCode);

    buffer.add(multihash);
    return buffer.toBytes();
  }

  /// Write varint to buffer
  static void _writeVarint(BytesBuilder buffer, int value) {
    while (value >= 0x80) {
      buffer.addByte((value & 0x7f) | 0x80);
      value >>= 7;
    }
    buffer.addByte(value & 0x7f);
  }

  /// Read varint from bytes
  ///
  /// Returns: (value, bytes_read)
  static (int, int) _readVarint(Uint8List bytes, int offset) {
    int value = 0;
    int shift = 0;
    int bytesRead = 0;

    while (offset + bytesRead < bytes.length) {
      final byte = bytes[offset + bytesRead];
      value |= (byte & 0x7f) << shift;
      bytesRead++;

      if ((byte & 0x80) == 0) {
        return (value, bytesRead);
      }

      shift += 7;
    }

    throw FormatException('Incomplete varint');
  }

  /// Encode bytes to base36 string
  static String _encodeBase36(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // Convert bytes to BigInt
    var num = BigInt.zero;
    for (final byte in bytes) {
      num = (num << 8) | BigInt.from(byte);
    }

    // Convert to base36
    if (num == BigInt.zero) return '0';

    final result = StringBuffer();
    final base = BigInt.from(36);

    while (num > BigInt.zero) {
      final remainder = (num % base).toInt();
      result.write(base36Alphabet[remainder]);
      num = num ~/ base;
    }

    return result.toString().split('').reversed.join();
  }

  /// Decode base36 string to bytes
  static Uint8List _decodeBase36(String str) {
    if (str.isEmpty) return Uint8List(0);

    // Convert base36 to BigInt
    var num = BigInt.zero;
    final base = BigInt.from(36);

    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      final digit = base36Alphabet.indexOf(char);
      if (digit == -1) {
        throw FormatException('Invalid base36 character: $char');
      }
      num = num * base + BigInt.from(digit);
    }

    // Convert BigInt to bytes
    if (num == BigInt.zero) return Uint8List.fromList([0]);

    final bytes = <int>[];
    while (num > BigInt.zero) {
      bytes.insert(0, (num & BigInt.from(0xff)).toInt());
      num = num >> 8;
    }

    return Uint8List.fromList(bytes);
  }

  /// Verify CID format is valid
  static bool isValidCid(String cid) {
    try {
      // Must start with 'k' (base36 prefix)
      if (!cid.startsWith('k') || cid.length < 10) {
        return false;
      }

      // Try to parse
      final bytes = cidToBytes(cid);

      // Must be at least version + codec + multihash header
      if (bytes.length < 4) {
        return false;
      }

      // Check version is 1
      if (bytes[0] != cidV1) {
        return false;
      }

      // Try to extract public key (full validation)
      publicKeyFromCid(cid);

      return true;
    } catch (e) {
      return false;
    }
  }
}

