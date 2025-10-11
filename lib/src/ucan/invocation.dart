/// UCAN invocation builder for Storacha capabilities
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/core/encoding.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ucan/capability.dart';

/// UCAN Invocation for executing capabilities
@immutable
class UcanInvocation {
  const UcanInvocation({
    required this.issuer,
    required this.audience,
    required this.capabilities,
    this.proofs = const [],
    this.expiration,
    this.nonce,
  });

  /// Issuer DID (the agent invoking)
  final String issuer;

  /// Audience DID (the service receiving)
  final String audience;

  /// Capabilities being invoked
  final List<Capability> capabilities;

  /// Proof UCANs (delegations)
  final List<String> proofs;

  /// Expiration timestamp (Unix seconds)
  final int? expiration;

  /// Nonce for uniqueness
  final String? nonce;

  /// Convert to JSON for encoding
  Map<String, dynamic> toJson() => {
        'v': '0.9.1',
        'iss': issuer,
        'aud': audience,
        'att': capabilities.map((c) => c.toJson()).toList(),
        if (proofs.isNotEmpty) 'prf': proofs,
        if (expiration != null) 'exp': expiration,
        if (nonce != null) 'nonce': nonce,
      };

  @override
  String toString() =>
      'UcanInvocation(iss: $issuer, aud: $audience, caps: ${capabilities.length})';
}

/// Builder for creating UCAN invocations
class InvocationBuilder {
  InvocationBuilder({
    required this.signer,
    this.audience = 'did:web:up.storacha.network',
  });

  /// Signer (agent) creating the invocation
  final Signer signer;

  /// Service audience
  final String audience;

  /// List of capabilities to invoke
  final List<Capability> _capabilities = [];

  /// Proof UCANs
  final List<String> _proofs = [];

  /// Add a capability to invoke
  void addCapability(Capability capability) {
    _capabilities.add(capability);
  }

  /// Add a proof UCAN
  void addProof(String proof) {
    _proofs.add(proof);
  }

  /// Build the invocation (without signing)
  UcanInvocation build({
    int? expiration,
    String? nonce,
  }) {
    if (_capabilities.isEmpty) {
      throw StateError('At least one capability must be added');
    }

    return UcanInvocation(
      issuer: signer.did().did(),
      audience: audience,
      capabilities: List.unmodifiable(_capabilities),
      proofs: List.unmodifiable(_proofs),
      expiration: expiration,
      nonce: nonce,
    );
  }

  /// Sign the invocation and return JWT
  ///
  /// Returns a JWT in the format: `header.payload.signature`
  /// - Header: `{"alg": "EdDSA", "typ": "JWT"}`
  /// - Payload: UCAN invocation JSON
  /// - Signature: Ed25519 signature of `header.payload`
  Future<String> sign({
    int? expiration,
    String? nonce,
  }) async {
    final invocation = build(
      expiration: expiration,
      nonce: nonce,
    );

    // Step 1: Create JWT header
    final header = {'alg': 'EdDSA', 'typ': 'JWT'};
    final headerEncoded = Base64Url.encodeString(json.encode(header));

    // Step 2: Create JWT payload (UCAN invocation)
    final payload = invocation.toJson();
    final payloadEncoded = Base64Url.encodeString(json.encode(payload));

    // Step 3: Sign the JWT
    final toSign = '$headerEncoded.$payloadEncoded';
    final signature = await signer.sign(utf8.encode(toSign));
    final signatureEncoded = Base64Url.encode(signature);

    // Step 4: Return complete JWT
    return '$toSign.$signatureEncoded';
  }
}

