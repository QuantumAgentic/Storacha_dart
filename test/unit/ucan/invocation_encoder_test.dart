import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/ucan/invocation_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('encodeInvocationToCar', () {
    test('encodes JWT to CAR format', () {
      const jwt = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.'
          'eyJ2IjoiMC45LjEiLCJpc3MiOiJkaWQ6a2V5OnouLi4ifQ.'
          'c2lnbmF0dXJl';

      final carBytes = encodeInvocationToCar(jwt);

      expect(carBytes, isNotEmpty);
      expect(carBytes, isA<Uint8List>());
    });

    test('produces valid CAR file structure', () {
      const jwt = 'simple.test.jwt';
      final carBytes = encodeInvocationToCar(jwt);

      // CAR files start with header length (varint)
      expect(carBytes[0], greaterThan(0));
      expect(carBytes.length, greaterThan(10));
    });

    test('different JWTs produce different CARs', () {
      const jwt1 = 'first.jwt.token';
      const jwt2 = 'second.jwt.token';

      final car1 = encodeInvocationToCar(jwt1);
      final car2 = encodeInvocationToCar(jwt2);

      expect(car1, isNot(equals(car2)));
    });

    test('same JWT produces same CAR (deterministic)', () {
      const jwt = 'deterministic.test.jwt';

      final car1 = encodeInvocationToCar(jwt);
      final car2 = encodeInvocationToCar(jwt);

      expect(car1, equals(car2));
    });
  });

  group('encodeInvocationWithBlocks', () {
    test('encodes JWT with no additional blocks', () {
      const jwt = 'test.jwt.token';

      final carBytes = encodeInvocationWithBlocks(jwt: jwt);

      expect(carBytes, isNotEmpty);
      expect(carBytes, isA<Uint8List>());
    });

    test('encodes JWT with additional blocks', () {
      const jwt = 'test.jwt.token';

      // Create a mock additional block
      final mockData = Uint8List.fromList([5, 6, 7, 8]);
      final mockCid = CID.createV1(rawCode, sha256Hash(mockData));
      final mockBlock = CARBlock(
        cid: mockCid,
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      );

      final carBytes = encodeInvocationWithBlocks(
        jwt: jwt,
        additionalBlocks: [mockBlock],
      );

      expect(carBytes, isNotEmpty);
      // Should be larger than single-block encoding
      final singleBlockCar = encodeInvocationToCar(jwt);
      expect(carBytes.length, greaterThan(singleBlockCar.length));
    });
  });
}

