/// Filecoin FR32 padding constants
///
/// FR32 (Filecoin Representation 32) is a padding scheme that converts
/// 127 bytes of data into 128 bytes by inserting 2-bit "shims" every 254 bits.
/// This ensures data fits within Filecoin's field element constraints.
library;

/// Number of input bytes per "quad" (block of 4 FR32 elements)
/// 127 bytes = 1016 bits = 4 × 254 bits
const int inBytesPerQuad = 127;

/// Number of output bytes per quad after FR32 padding
/// 128 bytes = 1024 bits = 4 × 256 bits
const int outBytesPerQuad = 128;

/// Number of bits in a field element (before padding)
const int inBitsFr = 254;

/// Number of bits in a field element (after padding)
const int outBitsFr = 256;

/// Ratio between unpadded and padded sizes
/// 254/256 = 127/128
const double frRatio = inBitsFr / outBitsFr;

/// Minimum payload size (must be at least 65 bytes for valid piece)
const int minPayloadSize = 65;
