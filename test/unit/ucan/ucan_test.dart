import 'dart:convert';

import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/ucan.dart';
import 'package:test/test.dart';

void main() {
  group('UCANHeader', () {
    test('creates header with defaults', () {
      const header = UCANHeader(version: '0.10.0', algorithm: 'EdDSA');

      expect(header.version, '0.10.0');
      expect(header.algorithm, 'EdDSA');
      expect(header.type, 'JWT');
    });

    test('fromJson / toJson round-trip', () {
      const original = UCANHeader(version: '0.10.0', algorithm: 'EdDSA');
      final json = original.toJson();
      final parsed = UCANHeader.fromJson(json);

      expect(parsed, equals(original));
    });

    test('encodes to base64url', () {
      const header = UCANHeader(version: '0.10.0', algorithm: 'EdDSA');
      final encoded = header.encode();

      // Should be base64url encoded JSON
      expect(encoded, isNotEmpty);
      expect(encoded, isNot(contains('=')));
    });
  });

  group('UCANPayload', () {
    test('creates payload with required fields', () {
      const payload = UCANPayload(
        issuer: 'did:key:z6Mkf...',
        audience: 'did:key:z6Mkg...',
        capabilities: [
          Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
        ],
        expiration: 1234567890,
      );

      expect(payload.issuer, 'did:key:z6Mkf...');
      expect(payload.audience, 'did:key:z6Mkg...');
      expect(payload.capabilities.length, 1);
      expect(payload.expiration, 1234567890);
    });

    test('fromJson / toJson round-trip', () {
      const original = UCANPayload(
        issuer: 'did:key:z6Mkf...',
        audience: 'did:key:z6Mkg...',
        capabilities: [
          Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
        ],
        expiration: 1234567890,
        nonce: 'test-nonce',
      );

      final json = original.toJson();
      final parsed = UCANPayload.fromJson(json);

      expect(parsed.issuer, original.issuer);
      expect(parsed.audience, original.audience);
      expect(parsed.expiration, original.expiration);
      expect(parsed.nonce, original.nonce);
    });

    test('isExpired checks expiration correctly', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1));
      final future = now.add(const Duration(hours: 1));

      final expiredPayload = UCANPayload(
        issuer: 'did:key:z6Mkf...',
        audience: 'did:key:z6Mkg...',
        capabilities: const [
          Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
        ],
        expiration: past.millisecondsSinceEpoch ~/ 1000,
      );

      final validPayload = UCANPayload(
        issuer: 'did:key:z6Mkf...',
        audience: 'did:key:z6Mkg...',
        capabilities: const [
          Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
        ],
        expiration: future.millisecondsSinceEpoch ~/ 1000,
      );

      expect(expiredPayload.isExpired(now), isTrue);
      expect(validPayload.isExpired(now), isFalse);
    });

    test('isNotYetValid checks notBefore correctly', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 1));
      final future = now.add(const Duration(hours: 1));

      final notYetValidPayload = UCANPayload(
        issuer: 'did:key:z6Mkf...',
        audience: 'did:key:z6Mkg...',
        capabilities: const [
          Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
        ],
        expiration: null,
        notBefore: future.millisecondsSinceEpoch ~/ 1000,
      );

      final validPayload = UCANPayload(
        issuer: 'did:key:z6Mkf...',
        audience: 'did:key:z6Mkg...',
        capabilities: const [
          Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
        ],
        expiration: null,
        notBefore: past.millisecondsSinceEpoch ~/ 1000,
      );

      expect(notYetValidPayload.isNotYetValid(now), isTrue);
      expect(validPayload.isNotYetValid(now), isFalse);
    });
  });

  group('UCAN', () {
    group('create', () {
      test('creates and signs UCAN', () async {
        final issuer = await Ed25519Signer.generate();
        final audience = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
        );

        expect(ucan.header.version, '0.10.0');
        expect(ucan.header.algorithm, 'EdDSA');
        expect(ucan.payload.issuer, issuer.did().did());
        expect(ucan.payload.audience, audience.did().did());
        expect(ucan.signature.length, 64);
      });

      test('creates UCAN with custom expiration', () async {
        final issuer = await Ed25519Signer.generate();
        const customExpiration = 2000000000;

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          expiration: customExpiration,
        );

        expect(ucan.payload.expiration, customExpiration);
      });

      test('creates UCAN with multiple capabilities', () async {
        final issuer = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
            Capability(with_: 'did:key:z6Mkf...', can: 'store/remove'),
            Capability(with_: 'did:key:z6Mkf...', can: 'upload/*'),
          ],
          lifetimeInSeconds: 3600,
        );

        expect(ucan.payload.capabilities.length, 3);
      });

      test('creates UCAN with facts and nonce', () async {
        final issuer = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
          nonce: 'unique-nonce-123',
          facts: const [
            {'claim': 'verified'},
          ],
        );

        expect(ucan.payload.nonce, 'unique-nonce-123');
        expect(ucan.payload.facts.length, 1);
      });
    });

    group('encode / parse', () {
      test('encodes UCAN to JWT string', () async {
        final issuer = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
        );

        final jwt = ucan.encode();

        // JWT format: header.payload.signature
        expect(jwt.split('.').length, 3);
      });

      test('parses JWT string to UCAN', () async {
        final issuer = await Ed25519Signer.generate();

        final original = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
        );

        final jwt = original.encode();
        final parsed = UCAN.parse(jwt);

        expect(parsed.header.version, original.header.version);
        expect(parsed.header.algorithm, original.header.algorithm);
        expect(parsed.payload.issuer, original.payload.issuer);
        expect(parsed.payload.audience, original.payload.audience);
        expect(parsed.signature, original.signature);
      });

      test('round-trip: UCAN -> JWT -> UCAN', () async {
        final issuer = await Ed25519Signer.generate();

        final original = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
          nonce: 'test-nonce',
        );

        final jwt = original.encode();
        final parsed = UCAN.parse(jwt);
        final jwt2 = parsed.encode();

        expect(jwt2, equals(jwt));
      });
    });

    group('verify', () {
      test('verifies valid signature', () async {
        final issuer = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
        );

        final isValid = await ucan.verify(issuer);
        expect(isValid, isTrue);
      });

      test('rejects tampered payload', () async {
        final issuer = await Ed25519Signer.generate();

        final original = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
        );

        // Tamper with payload
        final tamperedPayload = UCANPayload(
          issuer: original.payload.issuer,
          audience: 'did:key:z6TAMPERED...',
          capabilities: original.payload.capabilities,
          expiration: original.payload.expiration,
        );

        final tampered = UCAN(
          header: original.header,
          payload: tamperedPayload,
          signature: original.signature,
        );

        final isValid = await tampered.verify(issuer);
        expect(isValid, isFalse);
      });

      test('rejects signature from different signer', () async {
        final issuer1 = await Ed25519Signer.generate();
        final issuer2 = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: issuer1,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          lifetimeInSeconds: 3600,
        );

        final isValid = await ucan.verify(issuer2);
        expect(isValid, isFalse);
      });
    });

    group('validity checks', () {
      test('isValid returns true for valid UCAN', () async {
        final issuer = await Ed25519Signer.generate();
        final future = DateTime.now().add(const Duration(hours: 1));

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          expiration: future.millisecondsSinceEpoch ~/ 1000,
        );

        expect(ucan.isValid, isTrue);
        expect(ucan.isExpired, isFalse);
        expect(ucan.isNotYetValid, isFalse);
      });

      test('isExpired returns true for expired UCAN', () async {
        final issuer = await Ed25519Signer.generate();
        final past = DateTime.now().subtract(const Duration(hours: 1));

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: 'did:key:z6Mkg...',
          capabilities: const [
            Capability(with_: 'did:key:z6Mkf...', can: 'store/add'),
          ],
          expiration: past.millisecondsSinceEpoch ~/ 1000,
        );

        expect(ucan.isExpired, isTrue);
        expect(ucan.isValid, isFalse);
      });
    });

    group('integration', () {
      test('full UCAN workflow', () async {
        // Alice creates a UCAN for Bob
        final alice = await Ed25519Signer.generate();
        final bob = await Ed25519Signer.generate();

        final ucan = await UCAN.create(
          issuer: alice,
          audience: bob.did().did(),
          capabilities: const [
            Capability(
              with_: 'did:key:z6Mkspace...',
              can: 'store/add',
              nb: {'size': 1000000},
            ),
          ],
          lifetimeInSeconds: 3600,
        );

        // Encode to JWT
        final jwt = ucan.encode();

        // Bob receives and parses the UCAN
        final received = UCAN.parse(jwt);

        // Verify signature
        expect(await received.verify(alice), isTrue);

        // Check validity
        expect(received.isValid, isTrue);

        // Check claims
        expect(received.payload.issuer, alice.did().did());
        expect(received.payload.audience, bob.did().did());
        expect(received.payload.capabilities.length, 1);
        expect(received.payload.capabilities[0].can, 'store/add');
      });
    });
  });
}

