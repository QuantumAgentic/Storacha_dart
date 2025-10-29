import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart'
    hide carCode, dagCborCode;
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';

/// Encodes blocks into a Storacha-compatible sharded DAG structure.
///
/// This creates the "index/sharded/dag@0.1" format required by Storacha,
/// which wraps the actual content blocks in an index structure.
///
/// Format (DAG-CBOR):
/// ```
/// {
///   "index/sharded/dag@0.1": {
///     "shards": [<shard-CID>],
///     "content": <content-CID>
///   }
/// }
/// ```
class ShardEncoder {
  /// Encodes blocks into a single sharded CAR compatible with Storacha.
  ///
  /// For files smaller than the shard size (default 133 MB), this creates
  /// a single shard containing all blocks wrapped in an index structure.
  static Uint8List encodeSingleShard({
    required CID contentCid,
    required List<CARBlock> blocks,
  }) {
    // Step 1: Create shard block (DAG-CBOR array of multihashes representing slices)
    // This is a compact representation of the CAR blocks
    final shardBlock = _createShardBlock(blocks);
    
    // Step 2: Calculate CID of the shard block
    final shardMultihash = sha256Hash(shardBlock);
    final shardCid = CID.createV1(0x71 /* dagCborCode */, shardMultihash);

    // Step 3: Create the index block (DAG-CBOR)
    final indexBlock = _createIndexBlock(
      contentCid: contentCid,
      shardCid: shardCid,
    );

    // Step 4: Calculate CID of the index block
    final indexMultihash = sha256Hash(indexBlock);
    final indexCid = CID.createV1(0x71 /* dagCborCode */, indexMultihash);

    // Step 5: Create final CAR with index as root and both blocks
    final finalBlocks = [
      CARBlock(cid: indexCid, bytes: indexBlock),
      CARBlock(cid: shardCid, bytes: shardBlock),
    ];

    return encodeCar(
      roots: [indexCid],
      blocks: finalBlocks,
    );
  }

  /// Creates the shard block as a DAG-CBOR structure representing slices.
  ///
  /// Format: [header_multihash, [[m1, [offset1, len1]], [m2, [offset2, len2]], ...]]
  static Uint8List _createShardBlock(List<CARBlock> blocks) {
    if (blocks.isEmpty) {
      return Uint8List.fromList([0x80]); // empty array
    }
    
    // Create temporary CAR to calculate offsets
    final tempCar = encodeCar(
      roots: [blocks.first.cid],
      blocks: blocks,
    );
    
    // Calculate block offsets in the CAR
    final slices = <Map<String, dynamic>>[];
    var offset = 0;
    
    // Skip header
    var pos = 0;
    // Read header length varint
    var headerLength = 0;
    var shift = 0;
    while (pos < tempCar.length) {
      final b = tempCar[pos++];
      headerLength |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    offset = pos + headerLength;
    
    // Read each block
    for (final block in blocks) {
      final blockStart = offset;
      
      // Read block length varint
      var blockLength = 0;
      shift = 0;
      while (offset < tempCar.length) {
        final b = tempCar[offset++];
        blockLength |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      
      final blockEnd = offset + blockLength;
      slices.add({
        'multihash': block.cid.multihash,
        'offset': blockStart,
        'length': blockEnd - blockStart,
      });
      
      offset = blockEnd;
    }
    
    // Encode structure: [header_multihash, [slice_pairs]]
    final builder = BytesBuilder();
    builder.addByte(0x82); // array of 2
    
    // First item: header multihash (use first block's multihash)
    _encodeMultihash(builder, blocks.first.cid.multihash);
    
    // Second item: array of slice pairs
    final sliceCount = slices.length;
    if (sliceCount < 24) {
      builder.addByte(0x80 | sliceCount);
    } else if (sliceCount < 256) {
      builder
        ..addByte(0x98)
        ..addByte(sliceCount);
    }
    
    // Each slice: [multihash, [offset, length]]
    for (final slice in slices) {
      builder.addByte(0x82); // array of 2
      _encodeMultihash(builder, slice['multihash'] as MultihashDigest);
      
      builder.addByte(0x82); // array of 2 for [offset, length]
      _encodeCborInt(builder, slice['offset'] as int);
      _encodeCborInt(builder, slice['length'] as int);
    }
    
    return builder.toBytes();
  }
  
  /// Encodes a multihash as CBOR byte string.
  static void _encodeMultihash(BytesBuilder builder, MultihashDigest multihash) {
    final multihashBytes = multihash.bytes;
    final length = multihashBytes.length;
    
    if (length < 24) {
      builder.addByte(0x40 | length);
    } else if (length < 256) {
      builder
        ..addByte(0x58)
        ..addByte(length);
    } else {
      builder
        ..addByte(0x59)
        ..addByte((length >> 8) & 0xFF)
        ..addByte(length & 0xFF);
    }
    
    builder.add(multihashBytes);
  }
  
  /// Encodes an integer in CBOR format.
  static void _encodeCborInt(BytesBuilder builder, int value) {
    if (value < 24) {
      builder.addByte(value);
    } else if (value < 256) {
      builder
        ..addByte(0x18)
        ..addByte(value);
    } else if (value < 65536) {
      builder
        ..addByte(0x19)
        ..addByte((value >> 8) & 0xFF)
        ..addByte(value & 0xFF);
    } else if (value < 4294967296) {
      builder
        ..addByte(0x1A)
        ..addByte((value >> 24) & 0xFF)
        ..addByte((value >> 16) & 0xFF)
        ..addByte((value >> 8) & 0xFF)
        ..addByte(value & 0xFF);
    } else {
      // 64-bit
      builder
        ..addByte(0x1B)
        ..addByte((value >> 56) & 0xFF)
        ..addByte((value >> 48) & 0xFF)
        ..addByte((value >> 40) & 0xFF)
        ..addByte((value >> 32) & 0xFF)
        ..addByte((value >> 24) & 0xFF)
        ..addByte((value >> 16) & 0xFF)
        ..addByte((value >> 8) & 0xFF)
        ..addByte(value & 0xFF);
    }
  }

  /// Creates the index block in DAG-CBOR format.
  ///
  /// Structure:
  /// {
  ///   "index/sharded/dag@0.1": {
  ///     "shards": [<shard-CID>],
  ///     "content": <content-CID>
  ///   }
  /// }
  static Uint8List _createIndexBlock({
    required CID contentCid,
    required CID shardCid,
  }) {
    final builder = BytesBuilder();

    // Outer map: 1 key
    builder.addByte(0xA1);

    // Key: "index/sharded/dag@0.1" (21 chars)
    builder
      ..addByte(0x75)
      ..add('index/sharded/dag@0.1'.codeUnits);

    // Value: inner map with 2 keys (shards, content)
    // NOTE: JS client uses this order (not alphabetical), so we match it exactly
    builder.addByte(0xA2);

    // Key 1: "shards" (6 chars)
    builder
      ..addByte(0x66)
      ..add('shards'.codeUnits);

    // Value: array of 1 shard CID
    builder.addByte(0x81); // array of length 1
    _encodeCid(builder, shardCid);

    // Key 2: "content" (7 chars)
    builder
      ..addByte(0x67)
      ..add('content'.codeUnits);

    // Value: content CID as CBOR tag 42
    _encodeCid(builder, contentCid);

    return builder.toBytes();
  }

  /// Encodes a CID as CBOR tag 42 + bytes.
  static void _encodeCid(BytesBuilder builder, CID cid) {
    // CBOR tag 42 for CID
    builder
      ..addByte(0xD8)
      ..addByte(0x2A);

    final cidBytes = cid.bytes;
    final length = cidBytes.length + 1; // +1 for 0x00 prefix

    // Encode length
    if (length < 24) {
      builder.addByte(0x40 | length);
    } else if (length < 256) {
      builder
        ..addByte(0x58)
        ..addByte(length);
    } else {
      builder
        ..addByte(0x59)
        ..addByte((length >> 8) & 0xFF)
        ..addByte(length & 0xFF);
    }

    // Add multibase prefix and CID bytes
    builder
      ..addByte(0x00)
      ..add(cidBytes);
  }
}

