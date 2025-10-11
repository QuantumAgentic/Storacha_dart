import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:test/test.dart';

void main() {
  group('MultihashDigest', () {
    test('creates digest with all fields', () {
      final digest = Uint8List.fromList([1, 2, 3, 4]);
      final bytes = Uint8List.fromList([0x12, 0x04, 1, 2, 3, 4]);

      final multihash = MultihashDigest(
        code: 0x12,
        size: 4,
        digest: digest,
        bytes: bytes,
      );

      expect(multihash.code, equals(0x12));
      expect(multihash.size, equals(4));
      expect(multihash.digest, equals(digest));
      expect(multihash.bytes, equals(bytes));
    });

    test('equality works correctly', () {
      final digest = Uint8List.fromList([1, 2, 3, 4]);
      final bytes = Uint8List.fromList([0x12, 0x04, 1, 2, 3, 4]);

      final m1 = MultihashDigest(
        code: 0x12,
        size: 4,
        digest: digest,
        bytes: bytes,
      );

      final m2 = MultihashDigest(
        code: 0x12,
        size: 4,
        digest: digest,
        bytes: bytes,
      );

      expect(m1, equals(m2));
      expect(m1.hashCode, equals(m2.hashCode));
    });

    test('toString provides useful output', () {
      final digest = Uint8List.fromList([1, 2, 3, 4]);
      final bytes = Uint8List.fromList([0x12, 0x04, 1, 2, 3, 4]);

      final multihash = MultihashDigest(
        code: 0x12,
        size: 4,
        digest: digest,
        bytes: bytes,
      );

      expect(multihash.toString(), contains('0x12'));
      expect(multihash.toString(), contains('4'));
    });
  });

  group('createMultihash', () {
    test('creates valid multihash with SHA-256 code', () {
      final digest = Uint8List(32); // SHA-256 produces 32 bytes
      for (var i = 0; i < 32; i++) {
        digest[i] = i;
      }

      final multihash = createMultihash(0x12, digest);

      expect(multihash.code, equals(0x12));
      expect(multihash.size, equals(32));
      expect(multihash.digest, equals(digest));
      expect(multihash.bytes[0], equals(0x12)); // code
      expect(multihash.bytes[1], equals(32)); // size
      // code(1) + size(1) + digest(32) = 34
      expect(multihash.bytes.length, equals(34));
    });

    test('creates multihash with identity code', () {
      final data = Uint8List.fromList([1, 2, 3]);
      final multihash = createMultihash(0x00, data);

      expect(multihash.code, equals(0x00));
      expect(multihash.size, equals(3));
      expect(multihash.digest, equals(data));
    });

    test('handles empty digest', () {
      final digest = Uint8List(0);
      final multihash = createMultihash(0x12, digest);

      expect(multihash.size, equals(0));
      expect(multihash.digest.isEmpty, isTrue);
    });

    test('handles large digest', () {
      final digest = Uint8List(64); // SHA-512 size
      final multihash = createMultihash(0x13, digest);

      expect(multihash.code, equals(0x13));
      expect(multihash.size, equals(64));
    });
  });

  group('decodeMultihash', () {
    test('decodes valid SHA-256 multihash', () {
      // Create a known multihash
      final originalDigest = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        originalDigest[i] = i;
      }
      final original = createMultihash(0x12, originalDigest);

      // Decode it back
      final decoded = decodeMultihash(original.bytes);

      expect(decoded.code, equals(original.code));
      expect(decoded.size, equals(original.size));
      expect(decoded.digest, equals(original.digest));
      expect(decoded.bytes, equals(original.bytes));
    });

    test('decodes identity multihash', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final original = createMultihash(0x00, data);

      final decoded = decodeMultihash(original.bytes);

      expect(decoded.code, equals(0x00));
      expect(decoded.size, equals(5));
      expect(decoded.digest, equals(data));
    });

    test('throws on incorrect digest length', () {
      // Manually create invalid multihash (size mismatch)
      final badBytes = Uint8List.fromList([
        0x12, // SHA-256 code
        0x10, // Claims 16 bytes
        ...List.filled(10, 0), // But only has 10 bytes
      ]);

      expect(
        () => decodeMultihash(badBytes),
        throwsArgumentError,
      );
    });

    test('round-trip encode/decode preserves data', () {
      final testCases = [
        Uint8List.fromList([1, 2, 3]),
        Uint8List(32), // SHA-256 size
        Uint8List(64), // SHA-512 size
        Uint8List.fromList(List.generate(100, (i) => i % 256)),
      ];

      for (final digest in testCases) {
        final multihash = createMultihash(0x12, digest);
        final decoded = decodeMultihash(multihash.bytes);

        expect(decoded.code, equals(multihash.code));
        expect(decoded.size, equals(multihash.size));
        expect(decoded.digest, equals(multihash.digest));
      }
    });
  });

  group('Sha256Hasher', () {
    final hasher = sha256Hasher;

    test('has correct name and code', () {
      expect(hasher.name, equals('sha2-256'));
      expect(hasher.code, equals(0x12));
      expect(hasher.maxDigestLength, equals(32));
    });

    test('encodes data correctly', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final result = hasher.encode(input);

      expect(result.length, equals(32)); // SHA-256 is always 32 bytes
      expect(result, isNotEmpty);
    });

    test('produces consistent hashes', () {
      final input = Uint8List.fromList(utf8.encode('test'));
      final hash1 = hasher.encode(input);
      final hash2 = hasher.encode(input);

      expect(hash1, equals(hash2));
    });

    test('produces different hashes for different inputs', () {
      final input1 = Uint8List.fromList(utf8.encode('hello'));
      final input2 = Uint8List.fromList(utf8.encode('world'));

      final hash1 = hasher.encode(input1);
      final hash2 = hasher.encode(input2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('digest creates valid multihash', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final multihash = hasher.digest(input);

      expect(multihash.code, equals(0x12));
      expect(multihash.size, equals(32));
      expect(multihash.digest.length, equals(32));
      expect(multihash.bytes.length, greaterThan(32)); // Includes code & size
    });

    test('digest with truncate option', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final multihash = hasher.digest(
        input,
        const DigestOptions(truncate: 20),
      );

      expect(multihash.size, equals(20));
      expect(multihash.digest.length, equals(20));
    });

    test('digest throws on truncate below minimum', () {
      final input = Uint8List.fromList(utf8.encode('hello'));

      expect(
        () => hasher.digest(input, const DigestOptions(truncate: 10)),
        throwsArgumentError,
      );
    });

    test('digest throws on truncate above maximum', () {
      final input = Uint8List.fromList(utf8.encode('hello'));

      expect(
        () => hasher.digest(input, const DigestOptions(truncate: 40)),
        throwsArgumentError,
      );
    });

    test('digest throws on truncate above digest length', () {
      final input = Uint8List.fromList(utf8.encode('hello'));

      expect(
        () => hasher.digest(input, const DigestOptions(truncate: 33)),
        throwsArgumentError,
      );
    });
  });

  group('Sha512Hasher', () {
    final hasher = sha512Hasher;

    test('has correct name and code', () {
      expect(hasher.name, equals('sha2-512'));
      expect(hasher.code, equals(0x13));
      expect(hasher.maxDigestLength, equals(64));
    });

    test('encodes data correctly', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final result = hasher.encode(input);

      expect(result.length, equals(64)); // SHA-512 is always 64 bytes
    });

    test('produces consistent hashes', () {
      final input = Uint8List.fromList(utf8.encode('test'));
      final hash1 = hasher.encode(input);
      final hash2 = hasher.encode(input);

      expect(hash1, equals(hash2));
    });

    test('digest creates valid multihash', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final multihash = hasher.digest(input);

      expect(multihash.code, equals(0x13));
      expect(multihash.size, equals(64));
      expect(multihash.digest.length, equals(64));
    });
  });

  group('IdentityHasher', () {
    final hasher = identityHasher;

    test('has correct name and code', () {
      expect(hasher.name, equals('identity'));
      expect(hasher.code, equals(0x00));
      expect(hasher.minDigestLength, equals(0));
    });

    test('returns input unchanged', () {
      final input = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = hasher.encode(input);

      expect(result, equals(input));
    });

    test('digest creates valid multihash', () {
      final input = Uint8List.fromList([1, 2, 3, 4, 5]);
      final multihash = hasher.digest(input);

      expect(multihash.code, equals(0x00));
      expect(multihash.size, equals(5));
      expect(multihash.digest, equals(input));
    });
  });

  group('Hasher registry', () {
    test('getHasher returns correct hasher by code', () {
      expect(getHasher(0x00), equals(identityHasher));
      expect(getHasher(0x12), equals(sha256Hasher));
      expect(getHasher(0x13), equals(sha512Hasher));
    });

    test('getHasher returns null for unknown code', () {
      expect(getHasher(0xFF), isNull);
    });

    test('isHasherSupported returns true for supported codes', () {
      expect(isHasherSupported(0x00), isTrue);
      expect(isHasherSupported(0x12), isTrue);
      expect(isHasherSupported(0x13), isTrue);
    });

    test('isHasherSupported returns false for unsupported codes', () {
      expect(isHasherSupported(0xFF), isFalse);
    });
  });

  group('Convenience functions', () {
    test('sha256Hash creates SHA-256 multihash', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final multihash = sha256Hash(input);

      expect(multihash.code, equals(0x12));
      expect(multihash.size, equals(32));
    });

    test('sha512Hash creates SHA-512 multihash', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final multihash = sha512Hash(input);

      expect(multihash.code, equals(0x13));
      expect(multihash.size, equals(64));
    });

    test('hasCode checks multihash code correctly', () {
      final input = Uint8List.fromList(utf8.encode('hello'));
      final multihash = sha256Hash(input);

      expect(hasCode(multihash, 0x12), isTrue);
      expect(hasCode(multihash, 0x13), isFalse);
    });
  });

  group('Integration tests', () {
    test('create, encode, decode, verify pipeline', () {
      final input = Uint8List.fromList(utf8.encode('Hello, IPFS!'));

      // Hash with SHA-256
      final multihash = sha256Hash(input);

      // Verify multihash structure
      expect(multihash.code, equals(0x12));
      expect(multihash.size, equals(32));

      // Decode the multihash bytes
      final decoded = decodeMultihash(multihash.bytes);

      // Verify decoded matches original
      expect(decoded.code, equals(multihash.code));
      expect(decoded.size, equals(multihash.size));
      expect(decoded.digest, equals(multihash.digest));

      // Verify we can hash again and get same result
      final multihash2 = sha256Hash(input);
      expect(multihash2.bytes, equals(multihash.bytes));
    });

    test('different hashers produce different multihashes', () {
      final input = Uint8List.fromList(utf8.encode('test'));

      final sha256Digest = sha256Hash(input);
      final sha512Digest = sha512Hash(input);

      expect(sha256Digest.code, isNot(equals(sha512Digest.code)));
      expect(sha256Digest.size, isNot(equals(sha512Digest.size)));
      expect(sha256Digest.bytes, isNot(equals(sha512Digest.bytes)));
    });

    test('identity hasher preserves small data', () {
      final smallData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final multihash = identityHasher.digest(smallData);

      expect(multihash.digest, equals(smallData));
      expect(multihash.code, equals(0x00));

      // Decode and verify
      final decoded = decodeMultihash(multihash.bytes);
      expect(decoded.digest, equals(smallData));
    });
  });
}
