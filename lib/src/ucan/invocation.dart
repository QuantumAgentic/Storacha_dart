/// UCAN invocation builder for Storacha capabilities
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/invocation_ipld.dart';

/// Legacy UCAN Invocation (kept for compatibility, but not used for new invocations)
@immutable
@Deprecated('Use IPLDInvocation instead')
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

/// Builder for creating UCAN invocations (IPLD format)
/// 
/// This builder creates invocations in the ucanto/message@7.0.0 format,
/// not JWT. The old JWT format is deprecated.
class InvocationBuilder {
  InvocationBuilder({
    required this.signer,
    this.audience = 'did:web:up.storacha.network',
  }) : _ipldBuilder = IPLDInvocationBuilder(
          signer: signer,
          audience: audience,
        );

  /// Signer (agent) creating the invocation
  final Signer signer;

  /// Service audience
  final String audience;

  /// Internal IPLD builder
  final IPLDInvocationBuilder _ipldBuilder;

  /// Add a capability to invoke
  void addCapability(Capability capability) {
    _ipldBuilder.addCapability(capability);
  }

  /// Add a proof CID (from delegation)
  void addProof(String proofCid) {
    final cid = CID.parse(proofCid);
    _ipldBuilder.addProofCID(cid);
  }

  /// Add a proof archive (CAR bytes from delegation)
  void addProofArchive(Uint8List archive) {
    _ipldBuilder.addProofArchive(archive);
  }

  /// Get all proof archives
  List<Uint8List> get proofArchives => _ipldBuilder.proofArchives;

  /// Build and sign the invocation
  /// 
  /// Returns an IPLDInvocation (not a JWT string)
  Future<IPLDInvocation> build({
    int? expiration,
    String? nonce,
  }) async {
    return _ipldBuilder.build(
      expiration: expiration,
      nonce: nonce,
    );
  }

  /// Build a complete UCANTO message with this invocation
  /// 
  /// This creates the ucanto/message@7.0.0 structure with all proof blocks
  Future<UCNTOMessage> buildMessage({
    int? expiration,
    String? nonce,
  }) async {
    final invocation = await build(
      expiration: expiration,
      nonce: nonce,
    );

    final message = UCNTOMessage(invocations: [invocation]);
    
    // Add proof archives to the message
    for (final archive in _ipldBuilder.proofArchives) {
      message.addProofArchive(archive);
    }

    return message;
  }
}

