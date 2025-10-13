/// Improved CAR decoder based on @ipld/car reference implementation
/// 
/// Reference: node_modules/@ipld/car/src/buffer-decoder.js
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Result type for CAR decoding
typedef CARDecodeResult = ({CARHeader header, List<CARBlock> blocks});

/// Byte reader for CAR decoding
class _BytesReader {
  _BytesReader(this.bytes) : _pos = 0;

  final Uint8List bytes;
  int _pos;

  int get pos => _pos;

  Uint8List upTo(int length) {
    final end = _pos + length;
    if (end > bytes.length) {
      return bytes.sublist(_pos);
    }
    return bytes.sublist(_pos, end);
  }

  Uint8List exactly(int length, {bool seek = false}) {
    if (length > bytes.length - _pos) {
      throw Exception('Unexpected end of data');
    }

    final out = bytes.sublist(_pos, _pos + length);
    if (seek) {
      _pos += length;
    }
    return out;
  }

  void seekBy(int length) {
    _pos += length;
  }
}

/// Decode a CAR file from bytes
/// 
/// Based on @ipld/car/src/buffer-decoder.js:fromBytes()
CARDecodeResult decodeCarV2(Uint8List bytes) {
  final reader = _BytesReader(bytes);
  
  // Read header
  final header = _readHeader(reader);
  
  // Read blocks
  final blocks = <CARBlock>[];
  while (reader.upTo(8).isNotEmpty) {
    final blockHead = _readBlockHead(reader);
    final blockBytes = reader.exactly(blockHead.blockLength, seek: true);
    
    blocks.add(CARBlock(
      cid: blockHead.cid,
      bytes: blockBytes,
    ));
  }
  
  return (header: header, blocks: blocks);
}

/// Block header info
class _BlockHeader {
  const _BlockHeader({
    required this.cid,
    required this.length,
    required this.blockLength,
  });

  final CID cid;
  final int length;
  final int blockLength;
}

/// Read CAR header
/// 
/// Based on @ipld/car/src/buffer-decoder.js:readHeader()
CARHeader _readHeader(_BytesReader reader) {
  // Read varint length
  final lengthBytes = reader.upTo(8);
  final (length, bytesRead) = varint.decode(lengthBytes);
  
  // Skip the varint bytes
  reader.seekBy(bytesRead);
  
  if (length == 0) {
    throw FormatException('Invalid CAR header (zero length)');
  }
  
  // Read header bytes
  final headerBytes = reader.exactly(length, seek: true);
  
  // Decode DAG-CBOR header
  final header = _decodeDagCborHeader(headerBytes);
  
  return header;
}

/// Decode DAG-CBOR header
/// 
/// The header is a CBOR map with "version" and "roots" keys
CARHeader _decodeDagCborHeader(Uint8List bytes) {
  int offset = 0;
  
  // Read map header
  final mapHeader = bytes[offset++];
  int mapSize;
  
  if (mapHeader >= 0xa0 && mapHeader <= 0xb7) {
    mapSize = mapHeader & 0x1F;
  } else if (mapHeader == 0xb8) {
    mapSize = bytes[offset++];
  } else {
    throw FormatException(
      'Invalid CAR header: expected map, got 0x${mapHeader.toRadixString(16)}',
    );
  }
  
  int? version;
  List<CID>? roots;
  
  for (int i = 0; i < mapSize; i++) {
    // Read key (text string)
    final key = _readCborString(bytes, offset);
    offset += key.bytesRead;
    
    if (key.value == 'version') {
      // Read version (should be a small int)
      final versionByte = bytes[offset++];
      if (versionByte <= 0x17) {
        version = versionByte;
      } else {
        throw FormatException('Invalid version format');
      }
    } else if (key.value == 'roots') {
      // Read roots array
      final rootsResult = _readCborCidArray(bytes, offset);
      roots = rootsResult.cids;
      offset += rootsResult.bytesRead;
    } else {
      // Skip unknown key
      final skipResult = _skipCborValue(bytes, offset);
      offset += skipResult;
    }
  }
  
  if (version == null || roots == null) {
    throw FormatException('Invalid CAR header: missing version or roots');
  }
  
  return CARHeader(
    version: CARVersion.v1, // Only v1 is supported
    roots: roots,
  );
}

class _StringReadResult {
  const _StringReadResult(this.value, this.bytesRead);
  final String value;
  final int bytesRead;
}

/// Read CBOR text string
_StringReadResult _readCborString(Uint8List bytes, int offset) {
  final header = bytes[offset++];
  int bytesRead = 1;
  
  int length;
  if (header >= 0x60 && header <= 0x77) {
    length = header & 0x1F;
  } else if (header == 0x78) {
    length = bytes[offset++];
    bytesRead++;
  } else if (header == 0x79) {
    final high = bytes[offset++];
    final low = bytes[offset++];
    length = (high << 8) | low;
    bytesRead += 2;
  } else {
    throw FormatException('Invalid CBOR text string header');
  }
  
  final stringBytes = bytes.sublist(offset, offset + length);
  final value = utf8.decode(stringBytes);
  bytesRead += length;
  
  return _StringReadResult(value, bytesRead);
}

class _CidArrayResult {
  const _CidArrayResult(this.cids, this.bytesRead);
  final List<CID> cids;
  final int bytesRead;
}

/// Read CBOR array of CIDs
_CidArrayResult _readCborCidArray(Uint8List bytes, int offset) {
  final arrayHeader = bytes[offset++];
  int bytesRead = 1;
  
  int length;
  if (arrayHeader >= 0x80 && arrayHeader <= 0x97) {
    length = arrayHeader & 0x1F;
  } else if (arrayHeader == 0x98) {
    length = bytes[offset++];
    bytesRead++;
  } else {
    throw FormatException('Invalid CBOR array header');
  }
  
  final cids = <CID>[];
  for (int i = 0; i < length; i++) {
    // Read CID tag (0xd8 0x2a for tag 42)
    if (bytes[offset] == 0xd8 && bytes[offset + 1] == 0x2a) {
      offset += 2;
      bytesRead += 2;
    }
    
    // Read byte string with CID
    final cidResult = _readCborByteString(bytes, offset);
    offset += cidResult.bytesRead;
    bytesRead += cidResult.bytesRead;
    
    final cid = CID.decode(cidResult.value);
    cids.add(cid);
  }
  
  return _CidArrayResult(cids, bytesRead);
}

class _ByteStringResult {
  const _ByteStringResult(this.value, this.bytesRead);
  final Uint8List value;
  final int bytesRead;
}

/// Read CBOR byte string
_ByteStringResult _readCborByteString(Uint8List bytes, int offset) {
  final header = bytes[offset++];
  int bytesRead = 1;
  
  int length;
  if (header >= 0x40 && header <= 0x57) {
    length = header & 0x1F;
  } else if (header == 0x58) {
    length = bytes[offset++];
    bytesRead++;
  } else if (header == 0x59) {
    final high = bytes[offset++];
    final low = bytes[offset++];
    length = (high << 8) | low;
    bytesRead += 2;
  } else {
    throw FormatException('Invalid CBOR byte string header');
  }
  
  final value = bytes.sublist(offset, offset + length);
  bytesRead += length;
  
  return _ByteStringResult(value, bytesRead);
}

/// Skip a CBOR value (for unknown keys)
int _skipCborValue(Uint8List bytes, int offset) {
  final header = bytes[offset];
  
  // Simple int
  if (header <= 0x17) {
    return 1;
  }
  
  // Text string
  if (header >= 0x60 && header <= 0x77) {
    final length = header & 0x1F;
    return 1 + length;
  }
  
  // Byte string
  if (header >= 0x40 && header <= 0x57) {
    final length = header & 0x1F;
    return 1 + length;
  }
  
  // For other types, just return a safe skip amount
  // This is a simplified version
  return 1;
}

/// Read block header (CID + length info)
/// 
/// Based on @ipld/car/src/buffer-decoder.js:readBlockHead()
_BlockHeader _readBlockHead(_BytesReader reader) {
  final start = reader.pos;
  
  // Read block length (varint)
  final lengthBytes = reader.upTo(8);
  final (decodedLength, bytesRead) = varint.decode(lengthBytes);
  var length = decodedLength;
  
  if (length == 0) {
    throw FormatException('Invalid CAR section (zero length)');
  }
  
  // Advance past the varint
  reader.seekBy(bytesRead);
  
  length += (reader.pos - start);
  
  // Read CID
  final cid = _readCid(reader);
  
  final blockLength = length - (reader.pos - start);
  
  return _BlockHeader(
    cid: cid,
    length: length,
    blockLength: blockLength,
  );
}

/// Read CID from reader
/// 
/// Based on @ipld/car/src/buffer-decoder.js:readCid()
CID _readCid(_BytesReader reader) {
  // Peek at first 2 bytes
  final first = reader.upTo(2);
  
  // Check for CIDv0 (0x12 0x20 = sha256 with 32 bytes)
  if (first[0] == 0x12 && first[1] == 0x20) {
    // CIDv0: 32-byte SHA-256
    final bytes = reader.exactly(34, seek: true);
    return CID.decode(bytes);
  }
  
  // Read CIDv1
  // Version (varint)
  final versionBytes = reader.upTo(8);
  final (version, versionVarintLen) = varint.decode(versionBytes);
  
  if (version != 1) {
    throw FormatException('Unexpected CID version ($version)');
  }
  
  reader.seekBy(versionVarintLen);
  
  // Codec (varint)
  final codecBytes = reader.upTo(8);
  final (codec, codecVarintLen) = varint.decode(codecBytes);
  reader.seekBy(codecVarintLen);
  
  // Multihash code (varint)
  final hashCodeBytes = reader.upTo(8);
  final (hashCode, hashCodeVarintLen) = varint.decode(hashCodeBytes);
  
  // Multihash length (varint)
  final hashLenBytes = reader.upTo(8).sublist(hashCodeVarintLen);
  final (hashLength, hashLenVarintLen) = varint.decode(hashLenBytes);
  
  // Total multihash bytes = hash code varint + hash length varint + hash bytes
  final totalHashBytes = hashCodeVarintLen + hashLenVarintLen + hashLength;
  final multihashBytes = reader.exactly(totalHashBytes, seek: true);
  
  // Reconstruct full CID bytes: version + codec + multihash
  final cidBytes = Uint8List.fromList([
    ...varint.encode(version),
    ...varint.encode(codec),
    ...multihashBytes,
  ]);
  
  return CID.decode(cidBytes);
}

