import 'dart:typed_data';

import 'package:storacha_dart/src/crypto/did.dart';
import 'package:storacha_dart/src/crypto/ed25519_key_pair.dart';
import 'package:test/test.dart';

void main() {
  group('DIDKey', () {
    group('fromPublicKey', () {
      test('creates DIDKey from Ed25519 public key', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromPublicKey(keyPair.publicKey);

        expect(didKey.publicKey, equals(keyPair.publicKey));
        expect(didKey.code, ed25519Code);
      });

      test('throws on invalid public key length', () {
        expect(
          () => DIDKey.fromPublicKey(Uint8List(16)),
          throwsArgumentError,
        );

        expect(
          () => DIDKey.fromPublicKey(Uint8List(64)),
          throwsArgumentError,
        );
      });
    });

    group('fromKeyPair', () {
      test('creates DIDKey from Ed25519KeyPair', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);

        expect(didKey.publicKey, equals(keyPair.publicKey));
      });
    });

    group('did()', () {
      test('formats DID as did:key:z... (base58btc)', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);
        final didString = didKey.did();

        expect(didString, startsWith('did:key:z'));
        expect(didString.length, greaterThan(50)); // Base58btc encoded
      });

      test('toString() returns same as did()', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);

        expect(didKey.toString(), equals(didKey.did()));
      });

      test('produces same DID for same public key', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey1 = DIDKey.fromPublicKey(keyPair.publicKey);
        final didKey2 = DIDKey.fromPublicKey(keyPair.publicKey);

        expect(didKey1.did(), equals(didKey2.did()));
      });

      test('produces different DIDs for different keys', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.generate();

        final didKey1 = DIDKey.fromKeyPair(keyPair1);
        final didKey2 = DIDKey.fromKeyPair(keyPair2);

        expect(didKey1.did(), isNot(equals(didKey2.did())));
      });
    });

    group('parse()', () {
      test('parses valid did:key string', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final original = DIDKey.fromKeyPair(keyPair);
        final didString = original.did();

        final parsed = DIDKey.parse(didString);

        expect(parsed.did(), equals(original.did()));
        expect(parsed.publicKey, equals(original.publicKey));
      });

      test('round-trip: did() -> parse() -> did()', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);
        final didString = didKey.did();

        final parsed = DIDKey.parse(didString);
        final roundTripped = parsed.did();

        expect(roundTripped, equals(didString));
      });

      test('throws on invalid DID format', () {
        expect(
          () => DIDKey.parse('invalid-did'),
          throwsArgumentError,
        );

        expect(
          () => DIDKey.parse('did:invalid:z123'),
          throwsArgumentError,
        );
      });

      test('throws on did:key without base58btc prefix (z)', () {
        expect(
          () => DIDKey.parse('did:key:invalid'),
          throwsArgumentError,
        );
      });

      test('throws on unsupported key type', () {
        // Create a DID with RSA code (0x1205) instead of Ed25519 (0xed)
        const fakeDid = 'did:key:z4MXj1wBzi9jUstyPMS4jQqB6KdJaiatPkAtVt'
            'Gc6bQEQEEsKTic4G7Rou3iBf9vPmT5dbkm9qsZsuVNjq8HCuW1w';

        // This should fail because we only support Ed25519 (0xed)
        expect(
          () => DIDKey.parse(fakeDid),
          throwsArgumentError,
        );
      });
    });

    group('DID.parse() factory', () {
      test('parses did:key strings', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);
        final didString = didKey.did();

        final parsed = DID.parse(didString);

        expect(parsed, isA<DIDKey>());
        expect(parsed.did(), equals(didString));
      });

      test('throws on unsupported DID method', () {
        expect(
          () => DID.parse('did:web:example.com'),
          throwsArgumentError,
        );
      });

      test('throws on invalid DID', () {
        expect(
          () => DID.parse('not-a-did'),
          throwsArgumentError,
        );
      });
    });

    group('bytes()', () {
      test('returns multicodec-prefixed public key', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);
        final bytes = didKey.bytes();

        // Should start with Ed25519 code (0xed)
        expect(bytes[0], 0xed);
        // Should contain the public key
        expect(bytes.length, greaterThan(32));
      });

      test('bytes() -> publicKey extraction works', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);

        expect(didKey.publicKey, equals(keyPair.publicKey));
      });
    });

    group('equality', () {
      test('equal DIDKeys are equal', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey1 = DIDKey.fromPublicKey(keyPair.publicKey);
        final didKey2 = DIDKey.fromPublicKey(keyPair.publicKey);

        expect(didKey1, equals(didKey2));
        expect(didKey1.hashCode, equals(didKey2.hashCode));
      });

      test('different DIDKeys are not equal', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.generate();

        final didKey1 = DIDKey.fromKeyPair(keyPair1);
        final didKey2 = DIDKey.fromKeyPair(keyPair2);

        expect(didKey1, isNot(equals(didKey2)));
      });
    });

    group('integration', () {
      test('DID lifecycle: generate -> format -> parse -> verify', () async {
        // 1. Generate key pair
        final keyPair = await Ed25519KeyPair.generate();

        // 2. Create DID
        final didKey = DIDKey.fromKeyPair(keyPair);
        final didString = didKey.did();

        // 3. Parse DID back
        final parsedDid = DIDKey.parse(didString);

        // 4. Verify public key matches
        expect(parsedDid.publicKey, equals(keyPair.publicKey));

        // 5. Verify DID string matches
        expect(parsedDid.did(), equals(didString));
      });

      test('DID is stable across serialization', () async {
        final keyPair = await Ed25519KeyPair.generate();

        // Create DID multiple times from same key pair
        final didKey1 = DIDKey.fromKeyPair(keyPair);
        final didKey2 = DIDKey.fromPublicKey(keyPair.publicKey);

        // Serialize to string
        final didString1 = didKey1.did();
        final didString2 = didKey2.did();

        // Should be identical
        expect(didString1, equals(didString2));

        // Parse back
        final parsed1 = DIDKey.parse(didString1);
        final parsed2 = DIDKey.parse(didString2);

        // Should still be equal
        expect(parsed1, equals(parsed2));
        expect(parsed1.publicKey, equals(keyPair.publicKey));
      });

      test('real-world DID format matches spec', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final didKey = DIDKey.fromKeyPair(keyPair);
        final didString = didKey.did();

        // Verify format: did:key:z<base58btc>
        expect(didString, matches(r'^did:key:z[1-9A-HJ-NP-Za-km-z]+$'));

        // Verify length (typical did:key for Ed25519 is around 56 chars)
        expect(didString.length, greaterThanOrEqualTo(50));
        expect(didString.length, lessThanOrEqualTo(100));
      });
    });
  });
}
