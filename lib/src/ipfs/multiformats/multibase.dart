/// Multibase encoding/decoding
///
/// Implements multibase encoding with prefix character to indicate
/// the encoding. Based on multiformats/multibase specification.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Multibase codec interface
abstract class MultibaseCodec {
  /// Codec name (e.g., 'base58btc', 'base32')
  String get name;

  /// Prefix character (e.g., 'z' for base58btc, 'b' for base32)
  String get prefix;

  /// Encode bytes to multibase string (with prefix)
  String encode(Uint8List bytes);

  /// Decode multibase string (with prefix) to bytes
  Uint8List decode(String encoded);

  /// Encode bytes without prefix
  String encodeRaw(Uint8List bytes);

  /// Decode string without checking prefix
  Uint8List decodeRaw(String encoded);
}

/// Base58btc codec (Bitcoin alphabet)
///
/// Prefix: 'z'
/// Alphabet: 123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz
/// Used for CIDv0 and some CIDv1
class Base58BtcCodec implements MultibaseCodec {
  static const String _alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  @override
  String get name => 'base58btc';

  @override
  String get prefix => 'z';

  @override
  String encode(Uint8List bytes) => '$prefix${encodeRaw(bytes)}';

  @override
  Uint8List decode(String encoded) {
    if (!encoded.startsWith(prefix)) {
      throw ArgumentError(
        'Unable to decode multibase string "$encoded", '
        '$name decoder only supports inputs prefixed with $prefix',
      );
    }
    return decodeRaw(encoded.substring(prefix.length));
  }

  @override
  String encodeRaw(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }

    // Count leading zeros
    var zeroCount = 0;
    while (zeroCount < bytes.length && bytes[zeroCount] == 0) {
      zeroCount++;
    }

    // Convert bytes to big integer
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }

    // Convert to base58
    final result = StringBuffer();
    while (value > BigInt.zero) {
      final remainder = value % BigInt.from(58);
      value = value ~/ BigInt.from(58);
      result.write(_alphabet[remainder.toInt()]);
    }

    // Add leading '1' for each leading zero byte
    final leading = '1' * zeroCount;

    // Reverse (we built it backwards)
    return leading + result.toString().split('').reversed.join();
  }

  @override
  Uint8List decodeRaw(String encoded) {
    if (encoded.isEmpty) {
      return Uint8List(0);
    }

    // Count leading '1's
    var leadingOnes = 0;
    while (leadingOnes < encoded.length && encoded[leadingOnes] == '1') {
      leadingOnes++;
    }

    // Convert from base58 to big integer
    var value = BigInt.zero;
    for (var i = 0; i < encoded.length; i++) {
      final char = encoded[i];
      final index = _alphabet.indexOf(char);
      if (index == -1) {
        throw ArgumentError('Non-base58btc character: $char');
      }
      value = value * BigInt.from(58) + BigInt.from(index);
    }

    // Convert big integer to bytes
    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.add((value & BigInt.from(0xFF)).toInt());
      value = value >> 8;
    }

    // Add leading zero bytes
    final result = Uint8List(leadingOnes + bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      result[leadingOnes + i] = bytes[bytes.length - 1 - i];
    }

    return result;
  }
}

/// Base32 codec (RFC4648, lowercase, no padding)
///
/// Prefix: 'b'
/// Alphabet: abcdefghijklmnopqrstuvwxyz234567
/// Used for CIDv1
class Base32Codec implements MultibaseCodec {
  Base32Codec() {
    _alphabetIdx = {};
    for (var i = 0; i < _alphabet.length; i++) {
      _alphabetIdx[_alphabet[i]] = i;
    }
  }

  static const String _alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
  static const int _bitsPerChar = 5;

  late final Map<String, int> _alphabetIdx;

  @override
  String get name => 'base32';

  @override
  String get prefix => 'b';

  @override
  String encode(Uint8List bytes) => '$prefix${encodeRaw(bytes)}';

  @override
  Uint8List decode(String encoded) {
    if (!encoded.startsWith(prefix)) {
      throw ArgumentError(
        'Unable to decode multibase string "$encoded", '
        '$name decoder only supports inputs prefixed with $prefix',
      );
    }
    return decodeRaw(encoded.substring(prefix.length));
  }

  @override
  String encodeRaw(Uint8List data) {
    if (data.isEmpty) {
      return '';
    }

    const mask = (1 << _bitsPerChar) - 1;
    final result = StringBuffer();

    var bits = 0; // Number of bits currently in the buffer
    var buffer = 0; // Bits waiting to be written out, MSB first

    for (var i = 0; i < data.length; i++) {
      // Slurp data into the buffer
      buffer = (buffer << 8) | data[i];
      bits += 8;

      // Write out as much as we can
      while (bits >= _bitsPerChar) {
        bits -= _bitsPerChar;
        result.write(_alphabet[mask & (buffer >> bits)]);
      }
    }

    // Partial character
    if (bits != 0) {
      result.write(_alphabet[mask & (buffer << (_bitsPerChar - bits))]);
    }

    return result.toString();
  }

  @override
  Uint8List decodeRaw(String encoded) {
    if (encoded.isEmpty) {
      return Uint8List(0);
    }

    // Count the padding bytes (though base32 without pad shouldn't have them)
    var end = encoded.length;
    while (end > 0 && encoded[end - 1] == '=') {
      end--;
    }

    // Allocate the output
    final out = Uint8List((end * _bitsPerChar / 8).floor());

    // Parse the data
    var bits = 0; // Number of bits currently in the buffer
    var buffer = 0; // Bits waiting to be written out, MSB first
    var written = 0; // Next byte to write

    for (var i = 0; i < end; i++) {
      // Read one character from the string
      final value = _alphabetIdx[encoded[i]];
      if (value == null) {
        throw ArgumentError('Non-$name character: ${encoded[i]}');
      }

      // Append the bits to the buffer
      buffer = (buffer << _bitsPerChar) | value;
      bits += _bitsPerChar;

      // Write out some bits if the buffer has a byte's worth
      if (bits >= 8) {
        bits -= 8;
        out[written++] = 0xFF & (buffer >> bits);
      }
    }

    // Don't validate padding bits for base32 without padding
    // The JS implementation allows some flexibility here
    return out.sublist(0, written);
  }
}

/// Base64url codec (RFC4648, URL-safe, no padding)
///
/// Prefix: 'u'
/// Alphabet: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_
class Base64UrlCodec implements MultibaseCodec {
  Base64UrlCodec() {
    _alphabetIdx = {};
    for (var i = 0; i < _alphabet.length; i++) {
      _alphabetIdx[_alphabet[i]] = i;
    }
  }

  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  late final Map<String, int> _alphabetIdx;

  @override
  String get name => 'base64url';

  @override
  String get prefix => 'u';

  @override
  String encode(Uint8List bytes) => '$prefix${encodeRaw(bytes)}';

  @override
  Uint8List decode(String encoded) {
    if (!encoded.startsWith(prefix)) {
      throw ArgumentError(
        'Unable to decode multibase string "$encoded", '
        '$name decoder only supports inputs prefixed with $prefix',
      );
    }
    return decodeRaw(encoded.substring(prefix.length));
  }

  @override
  String encodeRaw(Uint8List data) {
    if (data.isEmpty) {
      return '';
    }

    // Use Dart's built-in base64Url encoder but remove padding
    return base64Url.encode(data).replaceAll('=', '');
  }

  @override
  Uint8List decodeRaw(String encoded) {
    if (encoded.isEmpty) {
      return Uint8List(0);
    }

    // Add back padding if needed for Dart's decoder
    final paddedBuffer = StringBuffer(encoded);
    while (paddedBuffer.length % 4 != 0) {
      paddedBuffer.write('=');
    }
    final padded = paddedBuffer.toString();

    try {
      return base64Url.decode(padded);
    } catch (e) {
      throw ArgumentError('Invalid base64url string: $e');
    }
  }
}

// Global codec instances
final base58btc = Base58BtcCodec();
final base32 = Base32Codec();
final base64url = Base64UrlCodec();

// Codec registry
final _codecs = <String, MultibaseCodec>{
  'z': base58btc, // base58btc
  'b': base32, // base32
  'u': base64url, // base64url
};

/// Encode bytes with specified codec
String multibaseEncode(Uint8List bytes, MultibaseCodec codec) =>
    codec.encode(bytes);

/// Decode multibase string (auto-detects encoding from prefix)
Uint8List multibaseDecode(String encoded) {
  if (encoded.isEmpty) {
    throw ArgumentError('Cannot decode empty string');
  }

  final prefix = encoded[0];
  final codec = _codecs[prefix];

  if (codec == null) {
    throw ArgumentError(
      'Unsupported multibase prefix: $prefix. '
      'Supported prefixes: ${_codecs.keys.join(", ")}',
    );
  }

  return codec.decode(encoded);
}

/// Get codec by prefix
MultibaseCodec? getMultibaseCodec(String prefix) => _codecs[prefix];

/// Check if prefix is supported
bool isMultibaseSupported(String prefix) => _codecs.containsKey(prefix);
