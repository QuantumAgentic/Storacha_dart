/// Sharded DAG Index for Storacha blob indexing
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:storacha_dart/src/core/dag_cbor_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';

/// Version identifier for the sharded DAG index format
const String kShardedDAGIndexVersion = 'index/sharded/dag@0.1';

/// Position of a slice within a shard (offset, length)
typedef Position = (int, int);

/// A sharded DAG index that maps content to its location in CAR shards.
///
/// This follows the Storacha blob-index format:
/// - Root block contains: { "index/sharded/dag@0.1": { content: <CID>, shards: [<CID>...] } }
/// - Each shard block contains: [<shardDigest>, [[<sliceDigest>, [offset, length]], ...]]
class ShardedDAGIndex {
  ShardedDAGIndex(this.content);

  /// The root CID of the content being indexed
  final CID content;

  /// Map of shard digest → (slice digest → position)
  final Map<MultihashDigest, Map<MultihashDigest, Position>> _shards = {};

  /// Sets the position of a slice within a shard.
  ///
  /// [shard] - The multihash digest of the CAR shard
  /// [slice] - The multihash digest of the slice (block) within the shard
  /// [position] - The (offset, length) of the slice in the shard
  void setSlice(MultihashDigest shard, MultihashDigest slice, Position position) {
    _shards.putIfAbsent(shard, () => <MultihashDigest, Position>{});
    _shards[shard]![slice] = position;
  }

  /// Archives the index into a CAR file.
  ///
  /// Returns the CAR bytes that can be uploaded as a blob.
  Future<Uint8List> archive() async {
    final roots = <CID>[];
    final blocks = <CARBlock>[];

    // Sort shards by digest for deterministic encoding
    final sortedShards = _shards.entries.toList()
      ..sort((a, b) => _compareBytes(a.key.bytes, b.key.bytes));

    // Create the index structure
    final indexData = <String, dynamic>{
      'content': content, // CID object (will be encoded as DAG-CBOR link)
      'shards': <CID>[],
    };

    // Encode each shard block
    for (final shardEntry in sortedShards) {
      final shardDigest = shardEntry.key;
      final slices = shardEntry.value;

      // Sort slices by digest for deterministic encoding
      final sortedSlices = slices.entries.toList()
        ..sort((a, b) => _compareBytes(a.key.bytes, b.key.bytes));

      // Format: [shardDigest, [[sliceDigest, [offset, length]], ...]]
      final slicesList = sortedSlices
          .map((e) => <dynamic>[
                e.key.bytes, // slice digest bytes
                <int>[e.value.$1, e.value.$2], // [offset, length]
              ])
          .toList();

      final shardBlockData = <dynamic>[
        shardDigest.bytes,
        slicesList,
      ];

      // Encode shard block as DAG-CBOR
      final shardBlockBytes = encodeDagCbor(shardBlockData);
      final shardBlockDigest = sha256Hash(shardBlockBytes);
      final shardBlockCid = CID.createV1(0x71, shardBlockDigest); // 0x71 = dag-cbor

      blocks.add(CARBlock(cid: shardBlockCid, bytes: shardBlockBytes));
      (indexData['shards'] as List<CID>).add(shardBlockCid);
    }

    // Encode root block as DAG-CBOR with version wrapper
    final rootData = <String, dynamic>{
      kShardedDAGIndexVersion: indexData,
    };
    final rootBytes = encodeDagCbor(rootData);
    final rootDigest = sha256Hash(rootBytes);
    final rootCid = CID.createV1(0x71, rootDigest); // 0x71 = dag-cbor

    roots.add(rootCid);
    blocks.insert(0, CARBlock(cid: rootCid, bytes: rootBytes));

    // Encode as CAR
    final indexCarBytes = encodeCar(roots: roots, blocks: blocks);
    
    // DEBUG: Save index CAR to file for inspection
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final indexPath = '/tmp/index_car_$timestamp.car';
      await File(indexPath).writeAsBytes(indexCarBytes);
      print('DEBUG: Saved index CAR to $indexPath');
    } catch (_) {}
    
    return indexCarBytes;
  }

  /// Compares two byte arrays lexicographically
  static int _compareBytes(Uint8List a, Uint8List b) {
    final minLength = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < minLength; i++) {
      if (a[i] != b[i]) {
        return a[i] - b[i];
      }
    }
    return a.length - b.length;
  }
}

/// Creates a new ShardedDAGIndex for the given content root.
ShardedDAGIndex createShardedDAGIndex(CID content) {
  return ShardedDAGIndex(content);
}

