import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/crypto/did.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:test/test.dart';

void main() {
  group('SignatureAlgorithm', () {
    test('has correct names', () {
      expect(SignatureAlgorithm.edDSA.name, 'EdDSA');
      expect(SignatureAlgorithm.rs256.name, 'RS256');
      expect(SignatureAlgorithm.es256.name, 'ES256');
    });
  });

  group('Ed25519Signer', () {
    group('generate', () {
      test('generates a valid signer', () async {
        final signer = await Ed25519Signer.generate();

        expect(signer.algorithm, SignatureAlgorithm.edDSA);
        expect(signer.publicKey.length, 32);
        expect(signer.privateKey.length, 32);
      });

      test('generates different signers each time', () async {
        final signer1 = await Ed25519Signer.generate();
        final signer2 = await Ed25519Signer.generate();

        expect(signer1.did().did(), isNot(equals(signer2.did().did())));
        expect(signer1.publicKey, isNot(equals(signer2.publicKey)));
      });
    });

    group('fromPrivateKey', () {
      test('creates signer from private key', () async {
        final signer1 = await Ed25519Signer.generate();
        final privateKey = signer1.privateKey;

        final signer2 = await Ed25519Signer.fromPrivateKey(privateKey);

        expect(signer2.publicKey, equals(signer1.publicKey));
        expect(signer2.did().did(), equals(signer1.did().did()));
      });

      test('throws on invalid private key', () {
        expect(
          () => Ed25519Signer.fromPrivateKey(Uint8List(16)),
          throwsArgumentError,
        );
      });
    });

    group('did()', () {
      test('returns valid DIDKey', () async {
        final signer = await Ed25519Signer.generate();
        final did = signer.did();

        expect(did, isA<DIDKey>());
        expect(did.did(), startsWith('did:key:z'));
      });

      test('DID matches public key', () async {
        final signer = await Ed25519Signer.generate();
        final did = signer.did();

        // DID should contain the public key
        if (did is DIDKey) {
          expect(did.publicKey, equals(signer.publicKey));
        }
      });
    });

    group('sign', () {
      test('signs a payload', () async {
        final signer = await Ed25519Signer.generate();
        final payload = utf8.encode('Test message');
        final signature = await signer.sign(Uint8List.fromList(payload));

        expect(signature.length, 64);
      });

      test('produces different signatures for different payloads', () async {
        final signer = await Ed25519Signer.generate();
        final payload1 = utf8.encode('Message 1');
        final payload2 = utf8.encode('Message 2');

        final sig1 = await signer.sign(Uint8List.fromList(payload1));
        final sig2 = await signer.sign(Uint8List.fromList(payload2));

        expect(sig1, isNot(equals(sig2)));
      });

      test('produces same signature for same payload', () async {
        final signer = await Ed25519Signer.generate();
        final payload = utf8.encode('Consistent payload');
        final payloadBytes = Uint8List.fromList(payload);

        final sig1 = await signer.sign(payloadBytes);
        final sig2 = await signer.sign(payloadBytes);

        expect(sig1, equals(sig2));
      });
    });

    group('verify', () {
      test('verifies valid signature', () async {
        final signer = await Ed25519Signer.generate();
        final payload = utf8.encode('Verify this');
        final payloadBytes = Uint8List.fromList(payload);

        final signature = await signer.sign(payloadBytes);
        final isValid = await signer.verify(payloadBytes, signature);

        expect(isValid, isTrue);
      });

      test('rejects tampered payload', () async {
        final signer = await Ed25519Signer.generate();
        final payload = utf8.encode('Original payload');
        final signature = await signer.sign(Uint8List.fromList(payload));

        final tamperedPayload = utf8.encode('Tampered payload');
        final isValid = await signer.verify(
          Uint8List.fromList(tamperedPayload),
          signature,
        );

        expect(isValid, isFalse);
      });

      test('rejects signature from different signer', () async {
        final signer1 = await Ed25519Signer.generate();
        final signer2 = await Ed25519Signer.generate();

        final payload = utf8.encode('Test payload');
        final payloadBytes = Uint8List.fromList(payload);

        final signature = await signer1.sign(payloadBytes);
        final isValid = await signer2.verify(payloadBytes, signature);

        expect(isValid, isFalse);
      });
    });

    group('export / import', () {
      test('exports signer to bytes', () async {
        final signer = await Ed25519Signer.generate();
        final exported = signer.export();

        expect(exported, isNotNull);
        expect(exported!.length, greaterThan(64));
      });

      test('imports signer from exported bytes', () async {
        final original = await Ed25519Signer.generate();
        final exported = original.export();

        final imported = await Ed25519Signer.import(exported!);

        expect(imported.publicKey, equals(original.publicKey));
        expect(imported.did().did(), equals(original.did().did()));
      });

      test('round-trip: export -> import -> export', () async {
        final original = await Ed25519Signer.generate();
        final exported1 = original.export();

        final imported = await Ed25519Signer.import(exported1!);
        final exported2 = imported.export();

        // Exported bytes should be identical
        expect(exported2, equals(exported1));
      });

      test('imported signer can sign and verify', () async {
        final original = await Ed25519Signer.generate();
        final exported = original.export();

        final imported = await Ed25519Signer.import(exported!);

        final payload = utf8.encode('Test after import');
        final payloadBytes = Uint8List.fromList(payload);

        // Sign with imported signer
        final signature = await imported.sign(payloadBytes);

        // Verify with both signers
        expect(await imported.verify(payloadBytes, signature), isTrue);
        expect(await original.verify(payloadBytes, signature), isTrue);
      });
    });

    group('algorithm', () {
      test('returns EdDSA', () async {
        final signer = await Ed25519Signer.generate();
        expect(signer.algorithm, SignatureAlgorithm.edDSA);
      });
    });

    group('integration', () {
      test('full signer lifecycle', () async {
        // 1. Generate signer
        final signer = await Ed25519Signer.generate();
        final did = signer.did().did();

        // 2. Export signer
        final exported = signer.export();
        expect(exported, isNotNull);

        // 3. Import signer
        final imported = await Ed25519Signer.import(exported!);
        expect(imported.did().did(), equals(did));

        // 4. Sign with original
        final message = utf8.encode('Important document');
        final messageBytes = Uint8List.fromList(message);
        final signature = await signer.sign(messageBytes);

        // 5. Verify with imported
        final isValid = await imported.verify(messageBytes, signature);
        expect(isValid, isTrue);

        // 6. Sign with imported
        final signature2 = await imported.sign(messageBytes);

        // 7. Verify with original
        final isValid2 = await signer.verify(messageBytes, signature2);
        expect(isValid2, isTrue);

        // 8. Both signatures should be identical
        expect(signature2, equals(signature));
      });

      test('simulate UCAN signing workflow', () async {
        // Alice creates a signer
        final alice = await Ed25519Signer.generate();
        final aliceDid = alice.did().did();

        // Alice signs a UCAN payload
        final ucanPayload = utf8.encode(
          '{"iss":"$aliceDid","aud":"did:key:z...","exp":1234567890}',
        );
        final ucanBytes = Uint8List.fromList(ucanPayload);

        final signature = await alice.sign(ucanBytes);

        // Bob verifies the UCAN (needs Alice's public key/DID)
        final bobVerifies = await alice.verify(ucanBytes, signature);
        expect(bobVerifies, isTrue);

        // Tampered UCAN should fail
        final tamperedUcan = utf8.encode(
          '{"iss":"$aliceDid","aud":"did:key:z...","exp":9999999999}',
        );
        final tamperedVerifies = await alice.verify(
          Uint8List.fromList(tamperedUcan),
          signature,
        );
        expect(tamperedVerifies, isFalse);
      });

      test('signer is deterministic from private key', () async {
        final signer1 = await Ed25519Signer.generate();
        final privateKey = signer1.privateKey;

        // Recreate signer from private key multiple times
        final signer2 = await Ed25519Signer.fromPrivateKey(privateKey);
        final signer3 = await Ed25519Signer.fromPrivateKey(privateKey);

        // All should have same DID
        expect(signer2.did().did(), equals(signer1.did().did()));
        expect(signer3.did().did(), equals(signer1.did().did()));

        // All should produce same signatures
        final message = utf8.encode('Deterministic test');
        final messageBytes = Uint8List.fromList(message);

        final sig1 = await signer1.sign(messageBytes);
        final sig2 = await signer2.sign(messageBytes);
        final sig3 = await signer3.sign(messageBytes);

        expect(sig2, equals(sig1));
        expect(sig3, equals(sig1));
      });
    });
  });
}

