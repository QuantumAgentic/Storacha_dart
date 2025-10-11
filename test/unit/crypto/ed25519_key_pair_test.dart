import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/crypto/ed25519_key_pair.dart';
import 'package:test/test.dart';

void main() {
  group('Ed25519KeyPair', () {
    group('generate', () {
      test('generates a valid key pair', () async {
        final keyPair = await Ed25519KeyPair.generate();

        expect(keyPair.publicKey.length, 32);
        expect(keyPair.privateKey.length, 32);
      });

      test('generates different key pairs each time', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.generate();

        expect(keyPair1.publicKey, isNot(equals(keyPair2.publicKey)));
        expect(keyPair1.privateKey, isNot(equals(keyPair2.privateKey)));
      });
    });

    group('fromPrivateKey', () {
      test('derives public key from private key', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.fromPrivateKey(
          keyPair1.privateKey,
        );

        expect(keyPair2.publicKey, equals(keyPair1.publicKey));
        expect(keyPair2.privateKey, equals(keyPair1.privateKey));
      });

      test('throws on invalid private key length', () async {
        expect(
          () => Ed25519KeyPair.fromPrivateKey(Uint8List(16)),
          throwsArgumentError,
        );

        expect(
          () => Ed25519KeyPair.fromPrivateKey(Uint8List(64)),
          throwsArgumentError,
        );
      });
    });

    group('sign', () {
      test('signs a message', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final message = utf8.encode('Hello, Storacha!');
        final signature = await keyPair.sign(Uint8List.fromList(message));

        expect(signature.length, 64);
      });

      test('produces different signatures for different messages', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final message1 = utf8.encode('Message 1');
        final message2 = utf8.encode('Message 2');

        final signature1 = await keyPair.sign(Uint8List.fromList(message1));
        final signature2 = await keyPair.sign(Uint8List.fromList(message2));

        expect(signature1, isNot(equals(signature2)));
      });

      test('produces same signature for same message', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final message = utf8.encode('Consistent message');

        final signature1 = await keyPair.sign(Uint8List.fromList(message));
        final signature2 = await keyPair.sign(Uint8List.fromList(message));

        expect(signature1, equals(signature2));
      });
    });

    group('verify', () {
      test('verifies valid signature', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final message = utf8.encode('Verify me!');
        final messageBytes = Uint8List.fromList(message);

        final signature = await keyPair.sign(messageBytes);
        final isValid = await keyPair.verify(messageBytes, signature);

        expect(isValid, isTrue);
      });

      test('rejects invalid signature', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final message = utf8.encode('Original message');
        final signature = await keyPair.sign(Uint8List.fromList(message));

        // Tamper with the message
        final tamperedMessage = utf8.encode('Tampered message');
        final isValid = await keyPair.verify(
          Uint8List.fromList(tamperedMessage),
          signature,
        );

        expect(isValid, isFalse);
      });

      test('rejects signature with different key pair', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.generate();
        final message = utf8.encode('Cross-key test');
        final messageBytes = Uint8List.fromList(message);

        final signature = await keyPair1.sign(messageBytes);
        final isValid = await keyPair2.verify(messageBytes, signature);

        expect(isValid, isFalse);
      });

      test('handles malformed signature gracefully', () async {
        final keyPair = await Ed25519KeyPair.generate();
        final message = utf8.encode('Test message');
        final badSignature = Uint8List(64); // All zeros

        final isValid = await keyPair.verify(
          Uint8List.fromList(message),
          badSignature,
        );

        expect(isValid, isFalse);
      });
    });

    group('equality', () {
      test('equal key pairs are equal', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.fromPrivateKey(
          keyPair1.privateKey,
        );

        expect(keyPair1, equals(keyPair2));
        expect(keyPair1.hashCode, equals(keyPair2.hashCode));
      });

      test('different key pairs are not equal', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final keyPair2 = await Ed25519KeyPair.generate();

        expect(keyPair1, isNot(equals(keyPair2)));
      });
    });

    group('integration', () {
      test('full sign-verify cycle with realistic data', () async {
        final keyPair = await Ed25519KeyPair.generate();

        // Simulate a real IPFS CID
        final cid = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';
        final message = utf8.encode(cid);
        final messageBytes = Uint8List.fromList(message);

        // Sign
        final signature = await keyPair.sign(messageBytes);

        // Verify with correct key
        expect(await keyPair.verify(messageBytes, signature), isTrue);

        // Verify fails with wrong key
        final otherKeyPair = await Ed25519KeyPair.generate();
        expect(await otherKeyPair.verify(messageBytes, signature), isFalse);
      });

      test('key pair is deterministic from same private key', () async {
        final keyPair1 = await Ed25519KeyPair.generate();
        final privateKey = keyPair1.privateKey;

        // Reconstruct key pair from private key
        final keyPair2 = await Ed25519KeyPair.fromPrivateKey(privateKey);
        final keyPair3 = await Ed25519KeyPair.fromPrivateKey(privateKey);

        expect(keyPair2.publicKey, equals(keyPair3.publicKey));

        // Signatures should be identical
        final message = utf8.encode('Test');
        final messageBytes = Uint8List.fromList(message);

        final sig2 = await keyPair2.sign(messageBytes);
        final sig3 = await keyPair3.sign(messageBytes);

        expect(sig2, equals(sig3));
      });
    });
  });
}

