/// Variable-length integer encoding (varint)
///
/// Implements the varint encoding used in multiformats and protobuf.
/// Each byte uses 7 bits for data and 1 bit (MSB) for continuation.
///
/// Based on multiformats/varint reference implementation.
library;

import 'dart:typed_data';

/// Most Significant Bit - marks continuation
const int _msb = 0x80;

/// Mask for extracting data bits (7 bits)
const int _rest = 0x7F;

/// All bits except REST
const int _msbAll = ~_rest;

/// Encode an integer as varint bytes
///
/// Returns a Uint8List containing the varint encoding of [value].
///
/// Example:
/// ```dart
/// final bytes = Varint.encode(300); // [0xAC, 0x02]
/// ```
Uint8List encode(int value) {
  if (value < 0) {
    throw ArgumentError('Varint encoding only supports non-negative integers');
  }

  final bytes = <int>[];
  var remaining = value;

  // Handle large numbers (>= 2^31)
  while (remaining >= 0x80000000) {
    bytes.add((remaining & 0xFF) | _msb);
    remaining = remaining ~/ 128;
  }

  // Handle remaining bytes
  while ((remaining & _msbAll) != 0) {
    bytes.add((remaining & 0xFF) | _msb);
    remaining >>= 7;
  }

  // Last byte (no continuation bit)
  bytes.add(remaining);

  return Uint8List.fromList(bytes);
}

/// Encode an integer directly into a target buffer
///
/// Writes the varint encoding of [value] into [target] starting at [offset].
/// Returns the [target] buffer for chaining.
///
/// Example:
/// ```dart
/// final buffer = Uint8List(10);
/// Varint.encodeTo(300, buffer, 0);
/// ```
Uint8List encodeTo(int value, Uint8List target, [int offset = 0]) {
  if (value < 0) {
    throw ArgumentError('Varint encoding only supports non-negative integers');
  }

  var currentOffset = offset;
  var remaining = value;

  // Handle large numbers (>= 2^31)
  while (remaining >= 0x80000000) {
    target[currentOffset++] = (remaining & 0xFF) | _msb;
    remaining = remaining ~/ 128;
  }

  // Handle remaining bytes
  while ((remaining & _msbAll) != 0) {
    target[currentOffset++] = (remaining & 0xFF) | _msb;
    remaining >>= 7;
  }

  // Last byte (no continuation bit)
  target[currentOffset] = remaining;

  return target;
}

/// Decode a varint from bytes
///
/// Returns a tuple of [value, bytesRead].
///
/// Throws [RangeError] if the varint is incomplete or malformed.
///
/// Example:
/// ```dart
/// final (value, bytesRead) = Varint.decode(Uint8List.fromList([0xAC, 0x02]));
/// // value = 300, bytesRead = 2
/// ```
(int, int) decode(Uint8List data, [int offset = 0]) {
  var result = 0;
  var shift = 0;
  var counter = offset;
  final length = data.length;

  while (true) {
    if (counter >= length) {
      throw RangeError('Could not decode varint: incomplete data');
    }

    final byte = data[counter++];

    // Add the data bits (lower 7 bits) to result
    if (shift < 28) {
      result += (byte & _rest) << shift;
    } else {
      // For large numbers, use multiplication instead of bit shift
      // to avoid overflow in Dart's 64-bit integers
      result += (byte & _rest) * (1 << shift);
    }

    shift += 7;

    // Check if this is the last byte (MSB not set)
    if (byte < _msb) {
      break;
    }

    // Safeguard against infinite loops on malformed data
    if (shift > 63) {
      throw RangeError('Varint too large: exceeds 64 bits');
    }
  }

  final bytesRead = counter - offset;
  return (result, bytesRead);
}

/// Calculate the number of bytes needed to encode a value
///
/// Returns the encoding length without actually encoding.
///
/// Example:
/// ```dart
/// final length = Varint.encodingLength(300); // 2
/// ```
int encodingLength(int value) {
  if (value < 0) {
    throw ArgumentError('Varint encoding only supports non-negative integers');
  }

  // Powers of 2 for quick calculation
  const n1 = 0x80; // 2^7
  const n2 = 0x4000; // 2^14
  const n3 = 0x200000; // 2^21
  const n4 = 0x10000000; // 2^28
  const n5 = 0x800000000; // 2^35
  const n6 = 0x40000000000; // 2^42
  const n7 = 0x2000000000000; // 2^49
  const n8 = 0x100000000000000; // 2^56
  const n9 = 0x8000000000000000; // 2^63

  if (value < n1) {
    return 1;
  }
  if (value < n2) {
    return 2;
  }
  if (value < n3) {
    return 3;
  }
  if (value < n4) {
    return 4;
  }
  if (value < n5) {
    return 5;
  }
  if (value < n6) {
    return 6;
  }
  if (value < n7) {
    return 7;
  }
  if (value < n8) {
    return 8;
  }
  if (value < n9) {
    return 9;
  }
  return 10;
}
