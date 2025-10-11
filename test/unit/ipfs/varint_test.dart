import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/varint.dart';
import 'package:test/test.dart';

void main() {
  group('Varint', () {
    group('encode', () {
      test('encodes 0', () {
        final bytes = encode(0);
        expect(bytes, equals([0x00]));
      });

      test('encodes 1', () {
        final bytes = encode(1);
        expect(bytes, equals([0x01]));
      });

      test('encodes 127', () {
        final bytes = encode(127);
        expect(bytes, equals([0x7F]));
      });

      test('encodes 128', () {
        final bytes = encode(128);
        expect(bytes, equals([0x80, 0x01]));
      });

      test('encodes 255', () {
        final bytes = encode(255);
        expect(bytes, equals([0xFF, 0x01]));
      });

      test('encodes 300', () {
        final bytes = encode(300);
        expect(bytes, equals([0xAC, 0x02]));
      });

      test('encodes 16384', () {
        final bytes = encode(16384);
        expect(bytes, equals([0x80, 0x80, 0x01]));
      });

      test('encodes large number (2^31)', () {
        final bytes = encode(0x80000000);
        expect(bytes.length, greaterThan(4));
        // Verify it's a valid varint
        final (decoded, _) = decode(bytes);
        expect(decoded, equals(0x80000000));
      });

      test('throws on negative numbers', () {
        expect(() => encode(-1), throwsArgumentError);
        expect(() => encode(-100), throwsArgumentError);
      });
    });

    group('encodeTo', () {
      test('encodes into target buffer', () {
        final target = Uint8List(10);
        encodeTo(300, target);
        expect(target[0], equals(0xAC));
        expect(target[1], equals(0x02));
      });

      test('encodes at specific offset', () {
        final target = Uint8List(10);
        encodeTo(300, target, 5);
        expect(target[5], equals(0xAC));
        expect(target[6], equals(0x02));
        expect(target[0], equals(0)); // Other bytes untouched
      });

      test('throws on negative numbers', () {
        final target = Uint8List(10);
        expect(() => encodeTo(-1, target), throwsArgumentError);
      });
    });

    group('decode', () {
      test('decodes 0', () {
        final (value, bytesRead) = decode(Uint8List.fromList([0x00]));
        expect(value, equals(0));
        expect(bytesRead, equals(1));
      });

      test('decodes 1', () {
        final (value, bytesRead) = decode(Uint8List.fromList([0x01]));
        expect(value, equals(1));
        expect(bytesRead, equals(1));
      });

      test('decodes 127', () {
        final (value, bytesRead) = decode(Uint8List.fromList([0x7F]));
        expect(value, equals(127));
        expect(bytesRead, equals(1));
      });

      test('decodes 128', () {
        final (value, bytesRead) = decode(Uint8List.fromList([0x80, 0x01]));
        expect(value, equals(128));
        expect(bytesRead, equals(2));
      });

      test('decodes 300', () {
        final (value, bytesRead) = decode(Uint8List.fromList([0xAC, 0x02]));
        expect(value, equals(300));
        expect(bytesRead, equals(2));
      });

      test('decodes 16384', () {
        final (value, bytesRead) =
            decode(Uint8List.fromList([0x80, 0x80, 0x01]));
        expect(value, equals(16384));
        expect(bytesRead, equals(3));
      });

      test('decodes from offset', () {
        final data = Uint8List.fromList([0xFF, 0xFF, 0xAC, 0x02, 0xFF]);
        final (value, bytesRead) = decode(data, 2);
        expect(value, equals(300));
        expect(bytesRead, equals(2));
      });

      test('throws on incomplete data', () {
        expect(
          () => decode(Uint8List.fromList([0x80])), // Missing continuation
          throwsRangeError,
        );
      });

      test('throws on empty data', () {
        expect(
          () => decode(Uint8List.fromList([])),
          throwsRangeError,
        );
      });

      test('throws on varint too large (>64 bits)', () {
        // Create a malformed varint with all continuation bits set
        final malformed = Uint8List.fromList(
          [...List.filled(15, 0x80), 0x00],
        );
        expect(
          () => decode(malformed),
          throwsRangeError,
        );
      });
    });

    group('encodingLength', () {
      test('calculates length for 1-byte values', () {
        expect(encodingLength(0), equals(1));
        expect(encodingLength(1), equals(1));
        expect(encodingLength(127), equals(1));
      });

      test('calculates length for 2-byte values', () {
        expect(encodingLength(128), equals(2));
        expect(encodingLength(255), equals(2));
        expect(encodingLength(300), equals(2));
        expect(encodingLength(16383), equals(2));
      });

      test('calculates length for 3-byte values', () {
        expect(encodingLength(16384), equals(3));
        expect(encodingLength(2097151), equals(3));
      });

      test('calculates length for 4-byte values', () {
        expect(encodingLength(2097152), equals(4));
        expect(encodingLength(268435455), equals(4));
      });

      test('calculates length for 5-byte values', () {
        expect(encodingLength(268435456), equals(5));
      });

      test('throws on negative numbers', () {
        expect(() => encodingLength(-1), throwsArgumentError);
      });
    });

    group('encode/decode round-trip', () {
      test('round-trips small values', () {
        for (var i = 0; i < 1000; i++) {
          final bytes = encode(i);
          final (decoded, _) = decode(bytes);
          expect(decoded, equals(i), reason: 'Failed for value $i');
        }
      });

      test('round-trips powers of 2', () {
        for (var power = 0; power < 20; power++) {
          final value = 1 << power;
          final bytes = encode(value);
          final (decoded, _) = decode(bytes);
          expect(decoded, equals(value), reason: 'Failed for 2^$power');
        }
      });

      test('round-trips large values', () {
        final testValues = [
          0xFFFFFF,
          0xFFFFFFFF,
          0xFFFFFFFFFF,
          0x7FFFFFFFFFFFFFFF, // Max safe integer
        ];

        for (final value in testValues) {
          final bytes = encode(value);
          final (decoded, _) = decode(bytes);
          expect(decoded, equals(value), reason: 'Failed for $value');
        }
      });
    });

    group('encoding length matches actual encoding', () {
      test('predicted length equals actual length', () {
        final testValues = [
          0,
          1,
          127,
          128,
          255,
          256,
          300,
          16384,
          1000000,
          0xFFFFFFFF,
        ];

        for (final value in testValues) {
          final predicted = encodingLength(value);
          final actual = encode(value).length;
          expect(
            predicted,
            equals(actual),
            reason: 'Length mismatch for $value',
          );
        }
      });
    });
  });
}
