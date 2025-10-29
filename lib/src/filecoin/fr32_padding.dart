/// FR32 padding implementation for Filecoin
///
/// Converts unpadded data into FR32-padded format by inserting 2-bit shims
/// every 254 bits to ensure compatibility with BLS12-381 field elements.
library;

import 'dart:typed_data';
import 'fr32_constants.dart';

/// Calculate the zero-padded size needed for a payload
///
/// The size must be:
/// 1. A power of 2
/// 2. Have enough room for FR32 padding (ratio 254:256)
int toZeroPaddedSize(int payloadSize) {
  final size = payloadSize < minPayloadSize ? minPayloadSize : payloadSize;

  // Find highest bit position
  final highestBit = (size.bitLength - 1);

  // Calculate bound for current power of 2
  final bound = (frRatio * (1 << (highestBit + 1))).ceil();

  // Return either current pow2 or next pow2 if we need more space
  if (size <= bound) {
    return bound;
  } else {
    return (frRatio * (1 << (highestBit + 2))).ceil();
  }
}

/// Calculate the FR32-padded piece size from unpadded size
int toPieceSize(int size) {
  return (toZeroPaddedSize(size) / frRatio).ceil();
}

/// Pad source bytes with FR32 padding
///
/// Takes 127-byte chunks and converts them to 128-byte chunks by inserting
/// 2-bit shims every 254 bits. This is the core of the FR32 encoding.
///
/// The algorithm processes data in "quads" (4 field elements):
/// - Input: 4 × 254 bits = 1016 bits = 127 bytes
/// - Output: 4 × 256 bits = 1024 bits = 128 bytes
///
/// The 2-bit shims are inserted at positions 254, 510, 766, and 1020.
///
/// IMPORTANT: This matches the JavaScript implementation which relies on
/// reading beyond source bounds returning 0 (undefined in JS coerces to 0).
/// We explicitly zero-pad the source first to achieve the same behavior.
Uint8List pad(Uint8List source) {
  final size = toZeroPaddedSize(source.length);
  final output = Uint8List(toPieceSize(source.length));

  // CRITICAL FIX: Zero-pad the source to the expected size
  // The JS implementation reads beyond bounds (gets undefined → 0)
  // We must explicitly create a zero-padded source to match that behavior
  final paddedSource = Uint8List(size);
  paddedSource.setRange(0, source.length, source);
  // Remaining bytes are already 0 (Uint8List default initialization)

  // Calculate number of quads in the source
  final quadCount = size ~/ inBytesPerQuad;

  // Process each quad (127 bytes → 128 bytes)
  for (int n = 0; n < quadCount; n++) {
    final readOffset = n * inBytesPerQuad;
    final writeOffset = n * outBytesPerQuad;

    // First FR32 element (31 bytes + 6 bits)
    // Copy first 32 bytes, then mask off top 2 bits of byte 31
    output.setRange(writeOffset, writeOffset + 32, paddedSource, readOffset);
    output[writeOffset + 31] &= 0x3F; // 0b00111111

    // Second FR32 element (bytes 32-63)
    // Shift left by 2 bits, carrying over last 2 bits from previous byte
    for (int i = 32; i < 64; i++) {
      output[writeOffset + i] =
          ((paddedSource[readOffset + i] << 2) |
           (paddedSource[readOffset + i - 1] >> 6)) & 0xFF;
    }
    output[writeOffset + 63] &= 0x3F;

    // Third FR32 element (bytes 64-95)
    // Shift left by 4 bits, carrying over last 4 bits from previous byte
    for (int i = 64; i < 96; i++) {
      output[writeOffset + i] =
          ((paddedSource[readOffset + i] << 4) |
           (paddedSource[readOffset + i - 1] >> 4)) & 0xFF;
    }
    output[writeOffset + 95] &= 0x3F;

    // Fourth FR32 element (bytes 96-126)
    // Shift left by 6 bits, carrying over last 6 bits from previous byte
    for (int i = 96; i < 127; i++) {
      output[writeOffset + i] =
          ((paddedSource[readOffset + i] << 6) |
           (paddedSource[readOffset + i - 1] >> 2)) & 0xFF;
    }

    // Fourth 2-bit shim at byte 127 (the last byte)
    // This is created by shifting byte 126 right by 2
    output[writeOffset + 127] = paddedSource[readOffset + 126] >> 2;
  }

  return output;
}
