import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';
import 'package:test/test.dart';

void main() {
  group('Base58btc', () {
    final codec = base58btc;

    group('encode', () {
      test('encodes empty bytes', () {
        final result = codec.encode(Uint8List(0));
        expect(result, equals('z'));
      });

      test('encodes single zero byte', () {
        final result = codec.encode(Uint8List.fromList([0]));
        expect(result, equals('z1'));
      });

      test('encodes "hello"', () {
        final bytes = Uint8List.fromList(utf8.encode('hello'));
        final result = codec.encode(bytes);
        expect(result, equals('zCn8eVZg'));
      });

      test('encodes "Hello World!"', () {
        final bytes = Uint8List.fromList(utf8.encode('Hello World!'));
        final result = codec.encode(bytes);
        expect(result, equals('z2NEpo7TZRRrLZSi2U'));
      });

      test('encodes bytes with leading zeros', () {
        final bytes = Uint8List.fromList([0, 0, 1, 2, 3]);
        final result = codec.encode(bytes);
        expect(result.startsWith('z11'), isTrue);
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        final result = codec.decode('z');
        expect(result, equals(Uint8List(0)));
      });

      test('decodes single zero', () {
        final result = codec.decode('z1');
        expect(result, equals(Uint8List.fromList([0])));
      });

      test('decodes "hello"', () {
        final result = codec.decode('zCn8eVZg');
        expect(utf8.decode(result), equals('hello'));
      });

      test('decodes "Hello World!"', () {
        final result = codec.decode('z2NEpo7TZRRrLZSi2U');
        expect(utf8.decode(result), equals('Hello World!'));
      });

      test('throws on invalid prefix', () {
        expect(
          () => codec.decode('bCn8eVZg'),
          throwsArgumentError,
        );
      });

      test('throws on invalid character', () {
        expect(
          () => codec.decode('z0OIl'),
          throwsArgumentError,
        );
      });
    });

    group('encode/decode round-trip', () {
      test('round-trips various byte patterns', () {
        final testCases = [
          Uint8List(0),
          Uint8List.fromList([0]),
          Uint8List.fromList([0, 0, 0]),
          Uint8List.fromList([1, 2, 3, 4, 5]),
          Uint8List.fromList([255, 254, 253]),
          Uint8List.fromList(utf8.encode('test')),
          Uint8List.fromList(utf8.encode('The quick brown fox')),
          Uint8List.fromList(List.generate(100, (i) => i % 256)),
        ];

        for (final original in testCases) {
          final encoded = codec.encode(original);
          final decoded = codec.decode(encoded);
          expect(decoded, equals(original), reason: 'Failed for $original');
        }
      });
    });
  });

  group('Base32', () {
    final codec = base32;

    group('encode', () {
      test('encodes empty bytes', () {
        final result = codec.encode(Uint8List(0));
        expect(result, equals('b'));
      });

      test('encodes "hello"', () {
        final bytes = Uint8List.fromList(utf8.encode('hello'));
        final result = codec.encode(bytes);
        expect(result, equals('bnbswy3dp'));
      });

      test('encodes "Hello World!"', () {
        final bytes = Uint8List.fromList(utf8.encode('Hello World!'));
        final result = codec.encode(bytes);
        expect(result, equals('bjbswy3dpeblw64tmmqqq'));
      });

      test('encodes single byte', () {
        final bytes = Uint8List.fromList([0xFF]);
        final result = codec.encode(bytes);
        expect(result, startsWith('b'));
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        final result = codec.decode('b');
        expect(result, equals(Uint8List(0)));
      });

      test('decodes "hello"', () {
        final result = codec.decode('bnbswy3dp');
        expect(utf8.decode(result), equals('hello'));
      });

      test('decodes "Hello World!"', () {
        final result = codec.decode('bjbswy3dpeblw64tmmqqq');
        expect(utf8.decode(result), equals('Hello World!'));
      });

      test('throws on invalid prefix', () {
        expect(
          () => codec.decode('znbswy3dp'),
          throwsArgumentError,
        );
      });

      test('throws on invalid character', () {
        expect(
          () => codec.decode('b189'),
          throwsArgumentError,
        );
      });
    });

    group('encode/decode round-trip', () {
      test('round-trips various byte patterns', () {
        final testCases = [
          Uint8List(0),
          Uint8List.fromList([0]),
          Uint8List.fromList([1, 2, 3, 4, 5]),
          Uint8List.fromList([255, 254, 253]),
          Uint8List.fromList(utf8.encode('test')),
          Uint8List.fromList(utf8.encode('The quick brown fox')),
          Uint8List.fromList(List.generate(100, (i) => i % 256)),
        ];

        for (final original in testCases) {
          final encoded = codec.encode(original);
          final decoded = codec.decode(encoded);
          expect(decoded, equals(original), reason: 'Failed for $original');
        }
      });
    });
  });

  group('Base64url', () {
    final codec = base64url;

    group('encode', () {
      test('encodes empty bytes', () {
        final result = codec.encode(Uint8List(0));
        expect(result, equals('u'));
      });

      test('encodes "hello"', () {
        final bytes = Uint8List.fromList(utf8.encode('hello'));
        final result = codec.encode(bytes);
        expect(result, equals('uaGVsbG8'));
      });

      test('encodes "Hello World!"', () {
        final bytes = Uint8List.fromList(utf8.encode('Hello World!'));
        final result = codec.encode(bytes);
        expect(result, equals('uSGVsbG8gV29ybGQh'));
      });

      test('encodes binary data', () {
        final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
        final result = codec.encode(bytes);
        expect(result, startsWith('u'));
        expect(result, isNot(contains('=')));
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        final result = codec.decode('u');
        expect(result, equals(Uint8List(0)));
      });

      test('decodes "hello"', () {
        final result = codec.decode('uaGVsbG8');
        expect(utf8.decode(result), equals('hello'));
      });

      test('decodes "Hello World!"', () {
        final result = codec.decode('uSGVsbG8gV29ybGQh');
        expect(utf8.decode(result), equals('Hello World!'));
      });

      test('throws on invalid prefix', () {
        expect(
          () => codec.decode('baGVsbG8'),
          throwsArgumentError,
        );
      });
    });

    group('encode/decode round-trip', () {
      test('round-trips various byte patterns', () {
        final testCases = [
          Uint8List(0),
          Uint8List.fromList([0]),
          Uint8List.fromList([1, 2, 3, 4, 5]),
          Uint8List.fromList([255, 254, 253]),
          Uint8List.fromList(utf8.encode('test')),
          Uint8List.fromList(utf8.encode('The quick brown fox')),
          Uint8List.fromList(List.generate(100, (i) => i % 256)),
        ];

        for (final original in testCases) {
          final encoded = codec.encode(original);
          final decoded = codec.decode(encoded);
          expect(decoded, equals(original), reason: 'Failed for $original');
        }
      });
    });
  });

  group('Multibase functions', () {
    test('decodes base58btc with prefix', () {
      final result = multibaseDecode('zCn8eVZg');
      expect(utf8.decode(result), equals('hello'));
    });

    test('decodes base32 with prefix', () {
      final result = multibaseDecode('bnbswy3dp');
      expect(utf8.decode(result), equals('hello'));
    });

    test('decodes base64url with prefix', () {
      final result = multibaseDecode('uaGVsbG8');
      expect(utf8.decode(result), equals('hello'));
    });

    test('throws on unsupported prefix', () {
      expect(
        () => multibaseDecode('xhello'),
        throwsArgumentError,
      );
    });

    test('throws on empty string', () {
      expect(
        () => multibaseDecode(''),
        throwsArgumentError,
      );
    });

    test('isMultibaseSupported returns true for supported prefixes', () {
      expect(isMultibaseSupported('z'), isTrue);
      expect(isMultibaseSupported('b'), isTrue);
      expect(isMultibaseSupported('u'), isTrue);
    });

    test('isMultibaseSupported returns false for unsupported prefixes', () {
      expect(isMultibaseSupported('x'), isFalse);
      expect(isMultibaseSupported(''), isFalse);
    });

    test('getMultibaseCodec returns correct codec', () {
      expect(getMultibaseCodec('z'), isNotNull);
      expect(getMultibaseCodec('z')?.name, equals('base58btc'));
      expect(getMultibaseCodec('b')?.name, equals('base32'));
      expect(getMultibaseCodec('u')?.name, equals('base64url'));
    });

    test('getMultibaseCodec returns null for unsupported prefix', () {
      expect(getMultibaseCodec('x'), isNull);
    });

    test('encode with specific codec', () {
      final bytes = Uint8List.fromList(utf8.encode('hello'));

      final base58Result = multibaseEncode(bytes, base58btc);
      expect(base58Result, equals('zCn8eVZg'));

      final base32Result = multibaseEncode(bytes, base32);
      expect(base32Result, equals('bnbswy3dp'));

      final base64Result = multibaseEncode(bytes, base64url);
      expect(base64Result, equals('uaGVsbG8'));
    });
  });

  group('Cross-codec compatibility', () {
    test('same data encodes differently with different codecs', () {
      final data = Uint8List.fromList(utf8.encode('test'));

      final base58Result = base58btc.encode(data);
      final base32Result = base32.encode(data);
      final base64Result = base64url.encode(data);

      // All should start with different prefixes
      expect(base58Result[0], equals('z'));
      expect(base32Result[0], equals('b'));
      expect(base64Result[0], equals('u'));

      // All should decode to the same data
      expect(multibaseDecode(base58Result), equals(data));
      expect(multibaseDecode(base32Result), equals(data));
      expect(multibaseDecode(base64Result), equals(data));
    });
  });
}
