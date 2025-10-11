import 'dart:typed_data';

import 'package:storacha_dart/src/core/encoding.dart';
import 'package:test/test.dart';

void main() {
  group('Base64Url', () {
    test('encodes bytes to base64url', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final encoded = Base64Url.encode(bytes);

      expect(encoded, isNotEmpty);
      expect(encoded, isNot(contains('=')));
    });

    test('decodes base64url to bytes', () {
      final original = Uint8List.fromList([1, 2, 3, 4]);
      final encoded = Base64Url.encode(original);
      final decoded = Base64Url.decode(encoded);

      expect(decoded, equals(original));
    });

    test('encodes and decodes strings', () {
      const original = 'Hello, World!';
      final encoded = Base64Url.encodeString(original);
      final decoded = Base64Url.decodeString(encoded);

      expect(decoded, equals(original));
    });

    test('handles padding correctly', () {
      final testCases = [
        [1],
        [1, 2],
        [1, 2, 3],
        [1, 2, 3, 4],
      ];

      for (final bytes in testCases) {
        final encoded = Base64Url.encode(bytes);
        final decoded = Base64Url.decode(encoded);
        expect(decoded, equals(bytes));
      }
    });

    test('produces URL-safe characters', () {
      final bytes = Uint8List.fromList(List.generate(256, (i) => i));
      final encoded = Base64Url.encode(bytes);

      expect(encoded, isNot(contains('+')));
      expect(encoded, isNot(contains('/')));
      expect(encoded, isNot(contains('=')));
    });
  });

  group('SimpleCborEncoder', () {
    test('encodes null', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(null);
      final bytes = encoder.toBytes();

      expect(bytes, equals([0xF6]));
    });

    test('encodes true', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(true);
      final bytes = encoder.toBytes();

      expect(bytes, equals([0xF5]));
    });

    test('encodes false', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(false);
      final bytes = encoder.toBytes();

      expect(bytes, equals([0xF4]));
    });

    test('encodes small positive integers', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(0);
      encoder.encode(1);
      encoder.encode(23);

      final bytes = encoder.toBytes();
      expect(bytes, equals([0x00, 0x01, 0x17]));
    });

    test('encodes larger positive integers', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(24);
      encoder.encode(255);
      encoder.encode(256);

      final bytes = encoder.toBytes();
      expect(bytes, equals([0x18, 24, 0x18, 255, 0x19, 0x01, 0x00]));
    });

    test('encodes strings', () {
      final encoder = SimpleCborEncoder();
      encoder.encode('hello');

      final bytes = encoder.toBytes();
      // 0x65 = string of length 5
      expect(bytes[0], equals(0x65));
      expect(bytes.sublist(1), equals('hello'.codeUnits));
    });

    test('encodes byte arrays', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(Uint8List.fromList([1, 2, 3]));

      final bytes = encoder.toBytes();
      // 0x43 = byte array of length 3
      expect(bytes[0], equals(0x43));
      expect(bytes.sublist(1), equals([1, 2, 3]));
    });

    test('encodes empty array', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(<dynamic>[]);

      final bytes = encoder.toBytes();
      expect(bytes, equals([0x80]));
    });

    test('encodes simple array', () {
      final encoder = SimpleCborEncoder();
      encoder.encode([1, 2, 3]);

      final bytes = encoder.toBytes();
      // 0x83 = array of length 3, followed by 1, 2, 3
      expect(bytes, equals([0x83, 0x01, 0x02, 0x03]));
    });

    test('encodes empty map', () {
      final encoder = SimpleCborEncoder();
      encoder.encode(<dynamic, dynamic>{});

      final bytes = encoder.toBytes();
      expect(bytes, equals([0xA0]));
    });

    test('encodes simple map', () {
      final encoder = SimpleCborEncoder();
      encoder.encode({'a': 1, 'b': 2});

      final bytes = encoder.toBytes();
      // 0xA2 = map with 2 entries
      expect(bytes[0], equals(0xA2));
    });

    test('encodes nested structures', () {
      final encoder = SimpleCborEncoder();
      encoder.encode({
        'name': 'Alice',
        'age': 30,
        'active': true,
      });

      final bytes = encoder.toBytes();
      // Should start with map header
      expect(bytes[0], equals(0xA3)); // map with 3 entries
    });
  });

  group('encodeCbor', () {
    test('convenience function works', () {
      final bytes = encodeCbor({'key': 'value'});
      expect(bytes, isNotEmpty);
    });

    test('encodes complex structure', () {
      final data = {
        'version': 1,
        'issuer': 'did:key:z...',
        'audience': 'did:web:service',
        'capabilities': [
          {'can': 'store/add', 'with': 'did:key:space'},
        ],
      };

      final bytes = encodeCbor(data);
      expect(bytes, isNotEmpty);
    });
  });
}

