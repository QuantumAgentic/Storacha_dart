/// DAG-UCAN decoder for Storacha CLI delegation format
/// 
/// Implements the format used by @ucanto/core and @ipld/dag-ucan
/// Reference: node_modules/@ucanto/core/src/delegation.js
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:storacha_dart/src/ipfs/car/car_decoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_decoder_v2.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/ucan.dart';

/// Simple byte reader for CBOR decoding
class _ByteReader {
  _ByteReader(Uint8List bytes)
      : _bytes = bytes,
        _offset = 0;

  final Uint8List _bytes;
  int _offset;

  int get remainingLength => _bytes.length - _offset;

  int readByte() {
    if (_offset >= _bytes.length) {
      throw RangeError('Attempted to read past end of buffer');
    }
    return _bytes[_offset++];
  }

  Uint8List readBytes(int count) {
    if (_offset + count > _bytes.length) {
      throw RangeError('Attempted to read past end of buffer');
    }
    final result = _bytes.sublist(_offset, _offset + count);
    _offset += count;
    return result;
  }
}

/// Result of extracting a UCAN delegation from a DAG-CBOR CAR archive
class DagUcanExtractionResult {
  const DagUcanExtractionResult({
    required this.ucan,
    required this.blocks,
    required this.archive,
  });

  /// The main UCAN delegation
  final UCAN ucan;

  /// All blocks in the CAR (including proofs)
  final Map<String, CARBlock> blocks;

  /// The original CAR archive bytes
  final Uint8List archive;
}

/// Extract a UCAN delegation from a DAG-CBOR CAR archive
/// 
/// This implements the format used by Storacha CLI with --base64 flag:
/// 1. Wrapper: 0x01 0x82 [header] [blocks] - CBOR array format
/// 2. First block contains CBOR variant: {'ucan@0.9.1': <link-to-ucan>}
/// 3. The link points to the actual UCAN block
/// 4. Other blocks contain the proof chain
/// 
/// Reference implementation:
/// @ucanto/core/src/delegation.js:extract()
DagUcanExtractionResult extractDagUcan(Uint8List carBytes) {
  try {
    // Check for the wrapper format: 0x01 0x82
    // This is a CBOR-encoded array wrapping the CAR data
    if (carBytes.length >= 2 && carBytes[0] == 0x01 && carBytes[1] == 0x82) {
      // Format after 0x01 0x82:
      // - Varint (1 byte usually): metadata length
      // - N bytes: metadata
      // - Rest: actual CAR data
      
      // Read metadata length
      int offset = 2;
      final metadataLen = carBytes[offset]; // For simplicity, assume 1 byte varint
      offset += 1;
      
      // Skip metadata bytes
      offset += metadataLen;
      
      // Extract actual CAR data
      final unwrappedBytes = Uint8List.fromList(carBytes.sublist(offset));
      return _extractFromWrappedCar(unwrappedBytes);
    }
    
    // Try standard CAR format
    final carResult = decodeCar(carBytes);

    if (carResult.blocks.isEmpty) {
      throw FormatException('CAR archive contains no blocks');
    }

    if (carResult.header.roots.isEmpty) {
      throw FormatException('CAR archive does not contain a root block');
    }

    // Get the root block (contains the variant)
    final rootCid = carResult.header.roots.first;
    CARBlock? rootBlock;

    for (final block in carResult.blocks) {
      if (block.cid == rootCid) {
        rootBlock = block;
        break;
      }
    }

    if (rootBlock == null) {
      throw FormatException(
        'Root CID $rootCid not found in CAR blocks',
      );
    }

    // Decode the variant from the root block
    // Format: {'ucan@0.9.1': <CID-link>}
    final variant = _decodeCborVariant(rootBlock.bytes);

    if (!variant.containsKey('ucan@0.9.1')) {
      throw FormatException(
        'Invalid delegation variant: missing "ucan@0.9.1" key',
      );
    }

    // Extract the UCAN CID from the variant
    final ucanCid = variant['ucan@0.9.1'];
    if (ucanCid is! CID) {
      throw FormatException(
        'Invalid delegation variant: "ucan@0.9.1" value is not a CID',
      );
    }

    // Find the UCAN block
    CARBlock? ucanBlock;
    for (final block in carResult.blocks) {
      if (block.cid == ucanCid) {
        ucanBlock = block;
        break;
      }
    }

    if (ucanBlock == null) {
      throw FormatException(
        'UCAN block with CID $ucanCid not found in CAR',
      );
    }

    // Decode the UCAN
    // Try CBOR first, then JWT (as per @ipld/dag-ucan decode())
    UCAN ucan;
    try {
      // Try as JWT first (more common)
      final jwtString = utf8.decode(ucanBlock.bytes);
      ucan = UCAN.parse(jwtString);
    } catch (e) {
      // If JWT parsing fails, might be CBOR-encoded UCAN
      // For now we only support JWT UCANs
      throw FormatException(
        'Failed to decode UCAN: only JWT format is currently supported. Error: $e',
      );
    }

    // Build blocks map (excluding root variant block)
    final blocksMap = <String, CARBlock>{};
    for (final block in carResult.blocks) {
      if (block.cid != rootCid) {
        blocksMap[block.cid.toString()] = block;
      }
    }

    return DagUcanExtractionResult(
      ucan: ucan,
      blocks: blocksMap,
      archive: carBytes,
    );
  } catch (e) {
    if (e is FormatException) rethrow;
    throw FormatException('Failed to extract DAG-UCAN: $e');
  }
}

/// Decode a CBOR variant map
/// 
/// The variant is a CBOR map with one entry: {'ucan@0.9.1': <CID>}
/// We need to decode the CID from the CBOR CID tag (42 = 0x2a)
Map<String, dynamic> _decodeCborVariant(Uint8List bytes) {
  final reader = _ByteReader(bytes);

  // Read CBOR map header
  final mapHeader = reader.readByte();

  int mapSize;
  if (mapHeader >= 0xa0 && mapHeader <= 0xb7) {
    // Map with length 0-23 embedded
    mapSize = mapHeader & 0x1F;
  } else if (mapHeader == 0xb8) {
    // Map with 1-byte length
    mapSize = reader.readByte();
  } else {
    throw FormatException(
      'Invalid CBOR map header: 0x${mapHeader.toRadixString(16)}',
    );
  }

  final result = <String, dynamic>{};

  for (int i = 0; i < mapSize; i++) {
    // Read key (text string)
    final key = _readCborString(reader);

    // Read value (should be a CID with tag 42)
    final value = _readCborValue(reader);

    result[key] = value;
  }

  return result;
}

/// Read a CBOR text string
String _readCborString(_ByteReader reader) {
  final header = reader.readByte();

  int length;
  if (header >= 0x60 && header <= 0x77) {
    // Text string with length 0-23 embedded
    length = header & 0x1F;
  } else if (header == 0x78) {
    // Text string with 1-byte length
    length = reader.readByte();
  } else if (header == 0x79) {
    // Text string with 2-byte length
    final high = reader.readByte();
    final low = reader.readByte();
    length = (high << 8) | low;
  } else {
    throw FormatException(
      'Invalid CBOR text string header: 0x${header.toRadixString(16)}',
    );
  }

  final bytes = reader.readBytes(length);
  return utf8.decode(bytes);
}

/// Read a CBOR value (handles CID tags)
dynamic _readCborValue(_ByteReader reader) {
  final header = reader.readByte();

  // Check for CID tag (42 = 0x2a)
  // Format: 0xd8 0x2a <byte-string>
  if (header == 0xd8) {
    final tagNumber = reader.readByte();
    if (tagNumber == 0x2a) {
      // CID tag - read the byte string containing the CID
      return _readCborCid(reader);
    }
    throw FormatException('Unsupported CBOR tag: $tagNumber');
  }

  // For other types, we'd need full CBOR decoding
  // For now, we only need CID support
  throw FormatException(
    'Unsupported CBOR value type: 0x${header.toRadixString(16)}',
  );
}

/// Read a CBOR-encoded CID
CID _readCborCid(_ByteReader reader) {
  final header = reader.readByte();

  int length;
  if (header >= 0x40 && header <= 0x57) {
    // Byte string with length 0-23 embedded
    length = header & 0x1F;
  } else if (header == 0x58) {
    // Byte string with 1-byte length
    length = reader.readByte();
  } else if (header == 0x59) {
    // Byte string with 2-byte length
    final high = reader.readByte();
    final low = reader.readByte();
    length = (high << 8) | low;
  } else {
    throw FormatException(
      'Invalid CBOR byte string header: 0x${header.toRadixString(16)}',
    );
  }

  final cidBytes = reader.readBytes(length);
  return CID.decode(cidBytes);
}

/// Extract from wrapped CAR format (Storacha CLI format)
/// 
/// The format after the 0x01 0x82 wrapper is a standard CAR file
DagUcanExtractionResult _extractFromWrappedCar(Uint8List bytes) {
  // Skip the 0x01 0x82 wrapper and decode as standard CAR
  final carResult = decodeCarV2(bytes);
  
  if (carResult.blocks.isEmpty) {
    throw FormatException('No blocks found in wrapped CAR');
  }
  
  if (carResult.header.roots.isEmpty) {
    throw FormatException('No roots found in CAR header');
  }
  
  // Find the root block (contains variant)
  final rootCid = carResult.header.roots.first;
  CARBlock? rootBlock;
  
  for (final block in carResult.blocks) {
    if (block.cid == rootCid) {
      rootBlock = block;
      break;
    }
  }
  
  if (rootBlock == null) {
    throw FormatException('Root block not found');
  }
  
  // Decode the variant from root block
  final variant = _decodeCborVariant(rootBlock.bytes);
  
  if (!variant.containsKey('ucan@0.9.1')) {
    throw FormatException('Invalid variant: missing ucan@0.9.1 key');
  }
  
  final ucanCid = variant['ucan@0.9.1'];
  if (ucanCid is! CID) {
    throw FormatException('Invalid variant: ucan@0.9.1 is not a CID');
  }
  
  // Find the UCAN block
  CARBlock? ucanBlock;
  for (final block in carResult.blocks) {
    if (block.cid == ucanCid) {
      ucanBlock = block;
      break;
    }
  }
  
  if (ucanBlock == null) {
    throw FormatException('UCAN block not found');
  }
  
  // Decode the UCAN (try JWT)
  final jwtString = utf8.decode(ucanBlock.bytes);
  final ucan = UCAN.parse(jwtString);
  
  // Build blocks map
  final blocksMap = <String, CARBlock>{};
  for (final block in carResult.blocks) {
    if (block.cid != rootCid) {
      blocksMap[block.cid.toString()] = block;
    }
  }
  
  return DagUcanExtractionResult(
    ucan: ucan,
    blocks: blocksMap,
    archive: Uint8List.fromList([0x01, 0x82, ...bytes]),
  );
}


