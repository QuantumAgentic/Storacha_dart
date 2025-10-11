import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:test/test.dart';

void main() {
  group('CARTypes', () {
    test('CARHeader equality', () {
      final cid1 = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final cid2 = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([2])));

      final header1 = CARHeader(version: CARVersion.v1, roots: [cid1]);
      final header2 = CARHeader(version: CARVersion.v1, roots: [cid1]);
      final header3 = CARHeader(version: CARVersion.v1, roots: [cid2]);

      expect(header1, equals(header2));
      expect(header1, isNot(equals(header3)));
    });

    test('CARBlock equality', () {
      final cid1 = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final cid2 = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([2])));

      final block1 = CARBlock(cid: cid1, bytes: Uint8List.fromList([1, 2, 3]));
      final block2 = CARBlock(cid: cid1, bytes: Uint8List.fromList([1, 2, 3]));
      final block3 = CARBlock(cid: cid2, bytes: Uint8List.fromList([1, 2, 3]));

      expect(block1, equals(block2));
      expect(block1, isNot(equals(block3)));
    });

    test('CARHeader toString', () {
      final cid = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final header = CARHeader(version: CARVersion.v1, roots: [cid]);

      expect(header.toString(), contains('CARHeader'));
      expect(header.toString(), contains('v1'));
    });

    test('CARBlock toString', () {
      final cid = CID.createV1(rawCode, sha256Hash(Uint8List.fromList([1])));
      final block = CARBlock(cid: cid, bytes: Uint8List.fromList([1, 2, 3]));

      expect(block.toString(), contains('CARBlock'));
      expect(block.toString(), contains('size: 3'));
    });
  });

  group('CAREncoder', () {
    test('encodes CAR with single root and single block', () {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);
      final cid = CID.createV1(rawCode, sha256Hash(data));

      final block = CARBlock(cid: cid, bytes: data);
      final carBytes = CAREncoder.encode(roots: [cid], blocks: [block]);

      // CAR should have content
      expect(carBytes, isNotEmpty);

      // Should start with header length (varint)
      expect(carBytes[0], greaterThan(0));
    });

    test('encodes CAR with multiple blocks', () {
      final data1 = Uint8List.fromList([0x01]);
      final data2 = Uint8List.fromList([0x02]);
      final data3 = Uint8List.fromList([0x03]);

      final cid1 = CID.createV1(rawCode, sha256Hash(data1));
      final cid2 = CID.createV1(rawCode, sha256Hash(data2));
      final cid3 = CID.createV1(rawCode, sha256Hash(data3));

      final blocks = [
        CARBlock(cid: cid1, bytes: data1),
        CARBlock(cid: cid2, bytes: data2),
        CARBlock(cid: cid3, bytes: data3),
      ];

      final carBytes = CAREncoder.encode(roots: [cid3], blocks: blocks);

      expect(carBytes, isNotEmpty);
    });

    test('encodes CAR with multiple roots', () {
      final data1 = Uint8List.fromList([0x01]);
      final data2 = Uint8List.fromList([0x02]);

      final cid1 = CID.createV1(rawCode, sha256Hash(data1));
      final cid2 = CID.createV1(rawCode, sha256Hash(data2));

      final blocks = [
        CARBlock(cid: cid1, bytes: data1),
        CARBlock(cid: cid2, bytes: data2),
      ];

      final carBytes = CAREncoder.encode(
        roots: [cid1, cid2],
        blocks: blocks,
      );

      expect(carBytes, isNotEmpty);
    });

    test('encodes CAR with empty blocks', () {
      final data = Uint8List(0);
      final cid = CID.createV1(rawCode, sha256Hash(data));

      final block = CARBlock(cid: cid, bytes: data);
      final carBytes = CAREncoder.encode(roots: [cid], blocks: [block]);

      expect(carBytes, isNotEmpty);
    });

    test('encodes CAR with large block', () {
      // 1 MB block
      final data = Uint8List.fromList(List.generate(1024 * 1024, (i) => i % 256));
      final cid = CID.createV1(rawCode, sha256Hash(data));

      final block = CARBlock(cid: cid, bytes: data);
      final carBytes = CAREncoder.encode(roots: [cid], blocks: [block]);

      expect(carBytes, isNotEmpty);
      // Should be roughly data size + header + CID + varint overhead
      expect(carBytes.length, greaterThan(data.length));
    });

    test('calculateSize matches encoded size', () {
      final data1 = Uint8List.fromList([0x01, 0x02, 0x03]);
      final data2 = Uint8List.fromList([0x04, 0x05]);

      final cid1 = CID.createV1(rawCode, sha256Hash(data1));
      final cid2 = CID.createV1(rawCode, sha256Hash(data2));

      final blocks = [
        CARBlock(cid: cid1, bytes: data1),
        CARBlock(cid: cid2, bytes: data2),
      ];

      final calculatedSize = CAREncoder.calculateSize(
        roots: [cid2],
        blocks: blocks,
      );

      final carBytes = CAREncoder.encode(
        roots: [cid2],
        blocks: blocks,
      );

      expect(carBytes.length, equals(calculatedSize));
    });

    test('calculateSize for various block counts', () {
      for (var count in [1, 5, 10, 100]) {
        final blocks = <CARBlock>[];
        final roots = <CID>[];

        for (var i = 0; i < count; i++) {
          final data = Uint8List.fromList([i % 256]);
          final cid = CID.createV1(rawCode, sha256Hash(data));
          blocks.add(CARBlock(cid: cid, bytes: data));
          if (i == count - 1) roots.add(cid);
        }

        final calculatedSize = CAREncoder.calculateSize(
          roots: roots,
          blocks: blocks,
        );

        final carBytes = CAREncoder.encode(
          roots: roots,
          blocks: blocks,
        );

        expect(
          carBytes.length,
          equals(calculatedSize),
          reason: 'Block count: $count',
        );
      }
    });

    test('encodes consistent CAR for same input', () {
      final data = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final cid = CID.createV1(rawCode, sha256Hash(data));
      final block = CARBlock(cid: cid, bytes: data);

      final car1 = CAREncoder.encode(roots: [cid], blocks: [block]);
      final car2 = CAREncoder.encode(roots: [cid], blocks: [block]);

      expect(car1, equals(car2));
    });

    test('encodes different CARs for different data', () {
      final data1 = Uint8List.fromList([0x01]);
      final data2 = Uint8List.fromList([0x02]);

      final cid1 = CID.createV1(rawCode, sha256Hash(data1));
      final cid2 = CID.createV1(rawCode, sha256Hash(data2));

      final car1 = CAREncoder.encode(
        roots: [cid1],
        blocks: [CARBlock(cid: cid1, bytes: data1)],
      );

      final car2 = CAREncoder.encode(
        roots: [cid2],
        blocks: [CARBlock(cid: cid2, bytes: data2)],
      );

      expect(car1, isNot(equals(car2)));
    });
  });

  group('Integration: CAR encoding with UnixFS', () {
    test('encodes a simple file as CAR', () {
      // Simulate a small file (single raw block)
      final fileData = Uint8List.fromList('Hello, CAR!'.codeUnits);
      final cid = CID.createV1(rawCode, sha256Hash(fileData));

      final block = CARBlock(cid: cid, bytes: fileData);
      final carBytes = CAREncoder.encode(roots: [cid], blocks: [block]);

      expect(carBytes, isNotEmpty);
      expect(carBytes.length, greaterThan(fileData.length));
    });

    test('encodes a chunked file as CAR', () {
      // Simulate a chunked file (DAG-PB root + raw leaves)
      final leaf1 = Uint8List.fromList([0x01, 0x02, 0x03]);
      final leaf2 = Uint8List.fromList([0x04, 0x05, 0x06]);
      final rootData = Uint8List.fromList([0xFF]); // Simulated DAG-PB node

      final cid1 = CID.createV1(rawCode, sha256Hash(leaf1));
      final cid2 = CID.createV1(rawCode, sha256Hash(leaf2));
      final rootCID = CID.createV1(dagPbCode, sha256Hash(rootData));

      final blocks = [
        CARBlock(cid: cid1, bytes: leaf1),
        CARBlock(cid: cid2, bytes: leaf2),
        CARBlock(cid: rootCID, bytes: rootData),
      ];

      final carBytes = CAREncoder.encode(roots: [rootCID], blocks: blocks);

      expect(carBytes, isNotEmpty);
    });

    test('calculates correct size for complex DAG', () {
      final blocks = <CARBlock>[];

      // Create 10 leaf blocks
      for (var i = 0; i < 10; i++) {
        final data = Uint8List.fromList([i, i, i]);
        final cid = CID.createV1(rawCode, sha256Hash(data));
        blocks.add(CARBlock(cid: cid, bytes: data));
      }

      // Add root block
      final rootData = Uint8List.fromList([0xAA, 0xBB]);
      final rootCID = CID.createV1(dagPbCode, sha256Hash(rootData));
      blocks.add(CARBlock(cid: rootCID, bytes: rootData));

      final size = CAREncoder.calculateSize(
        roots: [rootCID],
        blocks: blocks,
      );

      final encoded = CAREncoder.encode(
        roots: [rootCID],
        blocks: blocks,
      );

      expect(encoded.length, equals(size));
    });
  });
}

