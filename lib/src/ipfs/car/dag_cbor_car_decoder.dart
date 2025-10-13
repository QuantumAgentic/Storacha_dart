/// Decoder for DAG-CBOR encoded CAR files (used by Storacha CLI)
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:buffer/buffer.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';

/// Result of decoding a DAG-CBOR CAR file
class DagCborCarResult {
  const DagCborCarResult({
    required this.header,
    required this.blocks,
  });

  final CARHeader header;
  final List<CARBlock> blocks;
}

/// Decode a DAG-CBOR encoded CAR file
/// 
/// The Storacha CLI outputs delegations in this format:
/// - Byte 0: version/tag (0x01)
/// - Byte 1+: CBOR array [header, blocks...]
DagCborCarResult decodeDagCborCar(Uint8List bytes) {
  final reader = ByteDataReader();
  reader.add(bytes);

  // Skip the first byte (version/tag)
  final version = reader.readByte();
  if (version != 0x01) {
    throw FormatException(
      'Unsupported DAG-CBOR CAR version: 0x${version.toRadixString(16)}',
    );
  }

  // Read CBOR array header
  final arrayHeader = reader.readByte();
  if (arrayHeader != 0x82) {
    throw FormatException(
      'Expected CBOR array (0x82), got 0x${arrayHeader.toRadixString(16)}',
    );
  }

  // The array contains [header, blocks]
  // Read the header (CBOR map)
  final headerStartPos = reader.offset;
  final header = _readCborHeader(reader);

  // Read blocks
  final blocks = <CARBlock>[];
  while (reader.remainingLength > 0) {
    try {
      final block = _readCborBlock(reader);
      if (block != null) {
        blocks.add(block);
      }
    } catch (e) {
      // End of blocks or invalid block
      break;
    }
  }

  return DagCborCarResult(
    header: header,
    blocks: blocks,
  );
}

/// Read CBOR-encoded CAR header
CARHeader _readCborHeader(ByteDataReader reader) {
  final mapHeader = reader.readByte();
  
  // 0xa2 = map with 2 entries
  if (mapHeader != 0xa2) {
    throw FormatException(
      'Expected CBOR map (0xa2), got 0x${mapHeader.toRadixString(16)}',
    );
  }

  int? version;
  List<CID>? roots;

  // Read map entries
  for (int i = 0; i < 2; i++) {
    final keyLength = _readCborStringLength(reader);
    final keyBytes = reader.readBytes(keyLength);
    final key = utf8.decode(keyBytes);

    if (key == 'version') {
      version = reader.readByte(); // Simple int
    } else if (key == 'roots') {
      roots = _readCborArray(reader);
    } else {
      throw FormatException('Unknown header key: $key');
    }
  }

  if (version == null || roots == null) {
    throw FormatException('Invalid CAR header: missing version or roots');
  }

  return CARHeader(
    version: version == 1 ? CARVersion.v1 : CARVersion.v2,
    roots: roots,
  );
}

/// Read CBOR string length
int _readCborStringLength(ByteDataReader reader) {
  final header = reader.readByte();
  
  if (header >= 0x60 && header <= 0x77) {
    // Text string with length 0-23 embedded
    return header & 0x1F;
  } else if (header == 0x78) {
    // Text string with 1-byte length
    return reader.readByte();
  } else if (header == 0x79) {
    // Text string with 2-byte length
    final high = reader.readByte();
    final low = reader.readByte();
    return (high << 8) | low;
  } else {
    throw FormatException(
      'Unsupported CBOR string header: 0x${header.toRadixString(16)}',
    );
  }
}

/// Read CBOR array of CIDs
List<CID> _readCborArray(ByteDataReader reader) {
  final arrayHeader = reader.readByte();
  
  int length;
  if (arrayHeader >= 0x80 && arrayHeader <= 0x97) {
    // Array with length 0-23 embedded
    length = arrayHeader & 0x1F;
  } else if (arrayHeader == 0x98) {
    // Array with 1-byte length
    length = reader.readByte();
  } else {
    throw FormatException(
      'Unsupported CBOR array header: 0x${arrayHeader.toRadixString(16)}',
    );
  }

  final cids = <CID>[];
  for (int i = 0; i < length; i++) {
    // Read CID (usually tagged with 0xd82a for CID)
    final tag = reader.readByte();
    if (tag == 0xd8) {
      final tagNumber = reader.readByte();
      if (tagNumber != 0x2a) {
        throw FormatException('Expected CID tag (42), got $tagNumber');
      }
    }

    // Read byte string containing CID
    final cidLength = _readCborByteStringLength(reader);
    final cidBytes = reader.readBytes(cidLength);
    final cid = CID.decode(cidBytes);
    cids.add(cid);
  }

  return cids;
}

/// Read CBOR byte string length
int _readCborByteStringLength(ByteDataReader reader) {
  final header = reader.readByte();
  
  if (header >= 0x40 && header <= 0x57) {
    // Byte string with length 0-23 embedded
    return header & 0x1F;
  } else if (header == 0x58) {
    // Byte string with 1-byte length
    return reader.readByte();
  } else if (header == 0x59) {
    // Byte string with 2-byte length
    final high = reader.readByte();
    final low = reader.readByte();
    return (high << 8) | low;
  } else {
    throw FormatException(
      'Unsupported CBOR byte string header: 0x${header.toRadixString(16)}',
    );
  }
}

/// Read a CBOR-encoded CAR block
CARBlock? _readCborBlock(ByteDataReader reader) {
  if (reader.remainingLength < 10) {
    return null; // Not enough data for a block
  }

  try {
    // Blocks are stored as CBOR structures
    // Try to read CID and data
    
    // This is a simplified implementation
    // In reality, blocks might be encoded in various ways
    // For now, return null to skip block parsing
    return null;
  } catch (e) {
    return null;
  }
}

