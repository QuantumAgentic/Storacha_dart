/// UCAN invocation builder for Storacha capabilities
library;

import 'package:meta/meta.dart';
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
  /// TODO(network): Implement JWT signing
  Future<String> sign({
    int? expiration,
    String? nonce,
  }) async {
    build(
      expiration: expiration,
      nonce: nonce,
    );

    // TODO(network): Implement proper JWT encoding and signing
    // For now, throw unimplemented
    throw UnimplementedError(
      'UCAN JWT signing not yet implemented. '
      'Requires base64url encoding, CBOR, and Ed25519 signature.',
    );
  }
}

