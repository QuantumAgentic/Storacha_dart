import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:storacha_dart/storacha_dart.dart';

void main() {
  group('CAR Decoder', () {
    test('decode simple CAR file', () {
      // Create a simple CAR file with one block
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final cid = CID.createV1(rawCode, sha256Hash(data));

      // Encode
      final blocks = [CARBlock(cid: cid, bytes: data)];
      final carBytes = encodeCar(roots: [cid], blocks: blocks);

      // Decode
      final result = decodeCar(carBytes);

      expect(result.header.version, equals(CARVersion.v1));
      expect(result.header.roots.length, equals(1));
      expect(result.header.roots.first, equals(cid));
      expect(result.blocks.length, equals(1));
      expect(result.blocks.first.cid, equals(cid));
      expect(result.blocks.first.bytes, equals(data));
    });

    test('decode CAR file with multiple blocks', () {
      // Create CAR with 3 blocks
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([4, 5, 6]);
      final data3 = Uint8List.fromList([7, 8, 9]);

      final cid1 = CID.createV1(rawCode, sha256Hash(data1));
      final cid2 = CID.createV1(rawCode, sha256Hash(data2));
      final cid3 = CID.createV1(rawCode, sha256Hash(data3));

      final blocks = [
        CARBlock(cid: cid1, bytes: data1),
        CARBlock(cid: cid2, bytes: data2),
        CARBlock(cid: cid3, bytes: data3),
      ];

      // Encode
      final carBytes = encodeCar(roots: [cid1], blocks: blocks);

      // Decode
      final result = decodeCar(carBytes);

      expect(result.header.roots.length, equals(1));
      expect(result.header.roots.first, equals(cid1));
      expect(result.blocks.length, equals(3));

      expect(result.blocks[0].cid, equals(cid1));
      expect(result.blocks[0].bytes, equals(data1));

      expect(result.blocks[1].cid, equals(cid2));
      expect(result.blocks[1].bytes, equals(data2));

      expect(result.blocks[2].cid, equals(cid3));
      expect(result.blocks[2].bytes, equals(data3));
    });

    test('decode CAR file with multiple roots', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([4, 5, 6]);

      final cid1 = CID.createV1(rawCode, sha256Hash(data1));
      final cid2 = CID.createV1(rawCode, sha256Hash(data2));

      final blocks = [
        CARBlock(cid: cid1, bytes: data1),
        CARBlock(cid: cid2, bytes: data2),
      ];

      // Encode with 2 roots
      final carBytes = encodeCar(roots: [cid1, cid2], blocks: blocks);

      // Decode
      final result = decodeCar(carBytes);

      expect(result.header.roots.length, equals(2));
      expect(result.header.roots[0], equals(cid1));
      expect(result.header.roots[1], equals(cid2));
      expect(result.blocks.length, equals(2));
    });

    test('decode empty CAR file', () {
      // Create CAR with no blocks
      final carBytes = encodeCar(roots: [], blocks: []);

      // Decode
      final result = decodeCar(carBytes);

      expect(result.header.roots, isEmpty);
      expect(result.blocks, isEmpty);
    });

    test('roundtrip encode/decode', () {
      // Create multiple blocks
      final testData = [
        Uint8List.fromList([1, 2, 3, 4, 5]),
        Uint8List.fromList([6, 7, 8]),
        Uint8List.fromList([9, 10]),
        Uint8List.fromList([11]),
      ];

      final blocks = testData
          .map((data) => CARBlock(
                cid: CID.createV1(rawCode, sha256Hash(data)),
                bytes: data,
              ))
          .toList();

      final roots = [blocks.first.cid, blocks.last.cid];

      // Encode
      final carBytes = encodeCar(roots: roots, blocks: blocks);

      // Decode
      final result = decodeCar(carBytes);

      // Verify
      expect(result.header.roots, equals(roots));
      expect(result.blocks.length, equals(blocks.length));

      for (var i = 0; i < blocks.length; i++) {
        expect(result.blocks[i].cid, equals(blocks[i].cid));
        expect(result.blocks[i].bytes, equals(blocks[i].bytes));
      }
    });

    test('decode invalid CAR throws FormatException', () {
      // Invalid data
      final invalidBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF]);

      expect(
        () => decodeCar(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode truncated CAR throws error', () {
      // Create valid CAR
      final data = Uint8List.fromList([1, 2, 3]);
      final cid = CID.createV1(rawCode, sha256Hash(data));
      final blocks = [CARBlock(cid: cid, bytes: data)];
      final carBytes = encodeCar(roots: [cid], blocks: blocks);

      // Truncate it
      final truncated = carBytes.sublist(0, carBytes.length ~/ 2);

      expect(
        () => decodeCar(truncated),
        throwsA(isA<RangeError>()),
      );
    });

    test('decode large CAR file', () {
      // Create CAR with many blocks
      final blocks = <CARBlock>[];

      for (var i = 0; i < 100; i++) {
        final data = Uint8List.fromList(List.generate(1000, (j) => (i + j) % 256));
        final cid = CID.createV1(rawCode, sha256Hash(data));
        blocks.add(CARBlock(cid: cid, bytes: data));
      }

      final roots = [blocks.first.cid];

      // Encode
      final carBytes = encodeCar(roots: roots, blocks: blocks);

      // Decode
      final result = decodeCar(carBytes);

      expect(result.blocks.length, equals(100));
      expect(result.header.roots, equals(roots));

      // Verify all blocks
      for (var i = 0; i < blocks.length; i++) {
        expect(result.blocks[i].cid, equals(blocks[i].cid));
        expect(result.blocks[i].bytes, equals(blocks[i].bytes));
      }
    });
  });
}

