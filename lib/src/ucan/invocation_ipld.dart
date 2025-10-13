/// UCAN Invocation in IPLD/DAG-CBOR format (ucanto/message@7.0.0)
/// 
/// This replaces the old JWT-based invocation system.
/// Reference: @ucanto/core
library;

import 'dart:typed_data';
import 'package:storacha_dart/src/core/dag_cbor_encoder.dart' as dag_cbor;
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_reader.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/delegation.dart' show decodeSimpleDagCbor;
import 'package:storacha_dart/src/ucan/signature_payload.dart';

/// EdDSA signature multicodec code (0xd0ed)
const eddsaSignatureCode = 0xd0ed;

/// UCAN Invocation in IPLD format
class IPLDInvocation {
  IPLDInvocation({
    required this.issuer,
    required this.audience,
    required this.capabilities,
    required this.signature,
    this.proofs = const [],
    this.expiration,
    this.notBefore,
    this.nonce,
    this.facts = const [],
  });

  /// Issuer DID (the agent invoking)
  final String issuer;

  /// Audience DID (the service receiving)
  final String audience;

  /// Capabilities being invoked
  final List<Capability> capabilities;

  /// Signature bytes
  final Uint8List signature;

  /// Proof CIDs (references to delegations)
  final List<CID> proofs;

  /// Expiration timestamp (Unix seconds)
  final int? expiration;

  /// Not before timestamp
  final int? notBefore;

  /// Nonce for uniqueness
  final String? nonce;

  /// Facts (additional data)
  final List<Map<String, dynamic>> facts;

  /// Encode this invocation to DAG-CBOR
  Uint8List toDAGCBOR() {
    // Encode signature with multicodec prefix (varSig format)
    // Format: <signature-multicodec-varint><length-varint><signature-bytes>
    final signatureCodeBytes = varint.encode(eddsaSignatureCode);
    final signatureLengthBytes = varint.encode(signature.length);
    final encodedSignature = Uint8List.fromList([
      ...signatureCodeBytes,
      ...signatureLengthBytes,
      ...signature,
    ]);

    // IMPORTANT: Field order must match the reference client exactly!
    // Order: iss, aud, att, prf, exp, nbf (opt), fct (opt), nnc (opt), v, s
    final map = <String, dynamic>{
      'iss': dag_cbor.encodeDIDForCBOR(issuer),
      'aud': dag_cbor.encodeDIDForCBOR(audience),
      'att': capabilities.map((c) => c.toJson()).toList(),
    };

    // Add proofs if present
    if (proofs.isNotEmpty) {
      map['prf'] = proofs;
    }
    
    // Add expiration (always present)
    if (expiration != null) {
      map['exp'] = expiration;
    }
    
    // Add optional fields in order
    if (notBefore != null) {
      map['nbf'] = notBefore;
    }
    if (facts.isNotEmpty) {
      map['fct'] = facts;
    }
    if (nonce != null) {
      map['nnc'] = nonce;
    }
    
    // Add version and signature last
    map['v'] = '0.9.1';
    map['s'] = encodedSignature;

    return dag_cbor.encodeDagCbor(map);
  }

  /// Get the CID of this invocation
  CID get cid {
    final bytes = toDAGCBOR();
    final hash = sha256Hash(bytes);
    return CID.createV1(dag_cbor.dagCborCode, hash);
  }
}

/// UCANTO Message (ucanto/message@7.0.0)
class UCNTOMessage {
  UCNTOMessage({
    required this.invocations,
  });

  /// List of invocations in this message
  final List<IPLDInvocation> invocations;

  /// Archives of delegations (CAR bytes) to include as proof blocks
  final List<Uint8List> proofArchives = [];

  /// Add a proof archive
  void addProofArchive(Uint8List archive) {
    proofArchives.add(archive);
  }

  /// Encode the message root to DAG-CBOR
  Uint8List toDAGCBOR() {
    final map = {
      'ucanto/message@7.0.0': {
        'execute': invocations.map((inv) => inv.cid).toList(),
      }
    };

    return dag_cbor.encodeDagCbor(map);
  }

  /// Get the CID of the message root
  CID get rootCid {
    final bytes = toDAGCBOR();
    final hash = sha256Hash(bytes);
    return CID.createV1(dag_cbor.dagCborCode, hash);
  }

  /// Collect all IPLD blocks for this message
  List<CARBlock> collectBlocks() {
    final blocks = <CARBlock>[];
    final seenCids = <String>{};

    // Add blocks from proof archives first (delegations)
    for (final archive in proofArchives) {
      try {
        final carResult = readCar(archive);
        // Skip the root block if it's a variant wrapper (ucan@0.9.1)
        final rootCids = carResult.header.roots.map((c) => c.toString()).toSet();
        
        for (final block in carResult.blocks) {
          final cidStr = block.cid.toString();
          
          // Skip if already seen
          if (seenCids.contains(cidStr)) {
            continue;
          }
          
          // Skip variant root blocks (they're just wrappers)
          if (rootCids.contains(cidStr)) {
            try {
              final decoded = decodeSimpleDagCbor(block.bytes);
              if (decoded is Map && decoded.containsKey('ucan@0.9.1')) {
                // This is a variant wrapper, skip it
                continue;
              }
            } catch (_) {
              // If we can't decode, include the block to be safe
            }
          }
          
          blocks.add(block);
          seenCids.add(cidStr);
        }
      } catch (e) {
        // Skip invalid archives
        continue;
      }
    }

    // Add invocation blocks
    for (final invocation in invocations) {
      final invCid = invocation.cid;
      final cidStr = invCid.toString();
      if (!seenCids.contains(cidStr)) {
        blocks.add(CARBlock(
          cid: invCid,
          bytes: invocation.toDAGCBOR(),
        ));
        seenCids.add(cidStr);
      }
    }

    // Add message root block (must be last)
    final rootBlock = CARBlock(
      cid: rootCid,
      bytes: toDAGCBOR(),
    );
    blocks.add(rootBlock);

    return blocks;
  }

  /// Encode this message to CAR format
  Uint8List toCAR() {
    final blocks = collectBlocks();
    return encodeCar(
      roots: [rootCid],
      blocks: blocks,
    );
  }
}

/// Builder for creating IPLD invocations
class IPLDInvocationBuilder {
  IPLDInvocationBuilder({
    required this.signer,
    this.audience = 'did:web:up.storacha.network',
  });

  /// Signer (agent) creating the invocation
  final Signer signer;

  /// Service audience
  final String audience;

  /// List of capabilities to invoke
  final List<Capability> _capabilities = [];

  /// Proof CIDs (references to delegations)
  final List<CID> _proofCids = [];

  /// Proof archives (CAR bytes from delegations)
  final List<Uint8List> _proofArchives = [];

  /// Add a capability to invoke
  void addCapability(Capability capability) {
    _capabilities.add(capability);
  }

  /// Add a proof CID
  void addProofCID(CID cid) {
    _proofCids.add(cid);
  }

  /// Add a proof archive (CAR bytes)
  void addProofArchive(Uint8List archive) {
    _proofArchives.add(archive);
  }

  /// Get all proof archives
  List<Uint8List> get proofArchives => List.unmodifiable(_proofArchives);

  /// Build and sign the invocation
  Future<IPLDInvocation> build({
    int? expiration,
    String? nonce,
  }) async {
    if (_capabilities.isEmpty) {
      throw StateError('At least one capability must be added');
    }

    // Calculate expiration (default: 5 minutes from now)
    final exp = expiration ?? 
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 300;

    // Build the unsigned invocation data
    final issuerDid = signer.did().did();
    
    // Encode the signature payload (JWT-style header.payload)
    // This is what we actually sign, not the DAG-CBOR bytes!
    final signaturePayload = encodeSignaturePayload(
      issuer: issuerDid,
      audience: audience,
      capabilities: _capabilities,
      expiration: exp,
      proofs: _proofCids,
      nonce: nonce,
    );

    // Sign the JWT-style payload
    final signature = await signer.sign(signaturePayload);

    // Return the signed invocation
    return IPLDInvocation(
      issuer: issuerDid,
      audience: audience,
      capabilities: List.unmodifiable(_capabilities),
      signature: signature,
      proofs: List.unmodifiable(_proofCids),
      expiration: exp,
      nonce: nonce,
    );
  }
}

