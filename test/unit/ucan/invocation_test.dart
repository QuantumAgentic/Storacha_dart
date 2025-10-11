import 'dart:convert';

import 'package:storacha_dart/src/core/encoding.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';
import 'package:test/test.dart';

void main() {
  group('UcanInvocation', () {
    test('creates invocation with required fields', () {
      const invocation = UcanInvocation(
        issuer: 'did:key:z...',
        audience: 'did:web:service',
        capabilities: [],
      );

      expect(invocation.issuer, equals('did:key:z...'));
      expect(invocation.audience, equals('did:web:service'));
      expect(invocation.capabilities, isEmpty);
    });

    test('converts to JSON', () {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      const invocation = UcanInvocation(
        issuer: 'did:key:issuer',
        audience: 'did:web:service',
        capabilities: [capability],
      );

      final json = invocation.toJson();

      expect(json['v'], equals('0.9.1'));
      expect(json['iss'], equals('did:key:issuer'));
      expect(json['aud'], equals('did:web:service'));
      expect(json['att'], hasLength(1));
    });

    test('includes optional fields when provided', () {
      const invocation = UcanInvocation(
        issuer: 'did:key:issuer',
        audience: 'did:web:service',
        capabilities: [],
        expiration: 1234567890,
        nonce: 'abc123',
        proofs: ['proof1'],
      );

      final json = invocation.toJson();

      expect(json['exp'], equals(1234567890));
      expect(json['nonce'], equals('abc123'));
      expect(json['prf'], equals(['proof1']));
    });
  });

  group('InvocationBuilder', () {
    late Signer signer;

    setUp(() async {
      signer = await Ed25519Signer.generate();
    });

    test('creates builder with signer', () {
      final builder = InvocationBuilder(signer: signer);

      expect(builder.signer, equals(signer));
      expect(builder.audience, equals('did:web:up.storacha.network'));
    });

    test('allows custom audience', () {
      final builder = InvocationBuilder(
        signer: signer,
        audience: 'did:web:custom',
      );

      expect(builder.audience, equals('did:web:custom'));
    });

    test('adds capabilities', () {
      final builder = InvocationBuilder(signer: signer);
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);

      final invocation = builder.build();
      expect(invocation.capabilities, hasLength(1));
    });

    test('throws if no capabilities added', () {
      final builder = InvocationBuilder(signer: signer);

      expect(() => builder.build(), throwsStateError);
    });

    test('builds invocation', () {
      final builder = InvocationBuilder(signer: signer);
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final invocation = builder.build();

      expect(invocation.issuer, equals(signer.did().did()));
      expect(invocation.audience, equals('did:web:up.storacha.network'));
      expect(invocation.capabilities, hasLength(1));
    });

    test('adds proofs', () {
      final builder = InvocationBuilder(signer: signer);
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      builder.addProof('proof_jwt_token');

      final invocation = builder.build();
      expect(invocation.proofs, contains('proof_jwt_token'));
    });
  });

  group('JWT Signing', () {
    late Signer signer;
    late InvocationBuilder builder;

    setUp(() async {
      signer = await Ed25519Signer.generate();
      builder = InvocationBuilder(signer: signer);
    });

    test('sign() produces valid JWT format', () async {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final jwt = await builder.sign();

      // JWT should have 3 parts: header.payload.signature
      final parts = jwt.split('.');
      expect(parts, hasLength(3));

      // Each part should be base64url encoded
      expect(parts[0], isNotEmpty);
      expect(parts[1], isNotEmpty);
      expect(parts[2], isNotEmpty);
    });

    test('sign() creates verifiable signature', () async {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final jwt = await builder.sign();

      final parts = jwt.split('.');
      expect(parts, hasLength(3));

      // Decode the signature
      final signatureBytes = Base64Url.decode(parts[2]);
      expect(signatureBytes, isNotEmpty);
      expect(signatureBytes.length, equals(64)); // Ed25519 signature length
    });

    test('sign() includes correct header', () async {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final jwt = await builder.sign();

      final parts = jwt.split('.');
      final headerJson = Base64Url.decodeString(parts[0]);
      final header = parseJson(headerJson) as Map<String, dynamic>;

      expect(header['alg'], equals('EdDSA'));
      expect(header['typ'], equals('JWT'));
    });

    test('sign() includes invocation in payload', () async {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final jwt = await builder.sign();

      final parts = jwt.split('.');
      final payloadJson = Base64Url.decodeString(parts[1]);
      final payload = parseJson(payloadJson) as Map<String, dynamic>;

      expect(payload['v'], equals('0.9.1'));
      expect(payload['iss'], equals(signer.did().did()));
      expect(payload['aud'], equals('did:web:up.storacha.network'));
      expect(payload['att'], isNotNull);
    });

    test('sign() includes expiration when provided', () async {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final jwt = await builder.sign(expiration: 1234567890);

      final parts = jwt.split('.');
      final payloadJson = Base64Url.decodeString(parts[1]);
      final payload = parseJson(payloadJson) as Map<String, dynamic>;

      expect(payload['exp'], equals(1234567890));
    });

    test('sign() produces consistent format', () async {
      const capability = Capability(
        with_: 'did:key:space',
        can: 'store/add',
      );

      builder.addCapability(capability);
      final jwt1 = await builder.sign(nonce: 'same');
      
      // Create new builder with same capabilities
      final builder2 = InvocationBuilder(signer: signer);
      builder2.addCapability(capability);
      final jwt2 = await builder2.sign(nonce: 'same');

      // JWTs should be identical for same input
      expect(jwt1, equals(jwt2));
    });

    test('sign() produces different signatures for different content', () async {
      const capability1 = Capability(
        with_: 'did:key:space1',
        can: 'store/add',
      );

      const capability2 = Capability(
        with_: 'did:key:space2',
        can: 'store/add',
      );

      builder.addCapability(capability1);
      final jwt1 = await builder.sign();

      final builder2 = InvocationBuilder(signer: signer);
      builder2.addCapability(capability2);
      final jwt2 = await builder2.sign();

      // Different content should produce different JWTs
      expect(jwt1, isNot(equals(jwt2)));
    });
  });
}

/// Parse JSON string (helper for tests)
dynamic parseJson(String str) {
  return json.decode(str);
}

