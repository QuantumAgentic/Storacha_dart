/// Signer interface for signing payloads
///
/// This interface allows for injectable signers, enabling external key
/// management (IPNS keys, HSM, Secure Enclave, etc.).
library;

import 'dart:typed_data';

import 'package:storacha_dart/src/crypto/did.dart';
import 'package:storacha_dart/src/crypto/ed25519_key_pair.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Signature algorithm identifiers
enum SignatureAlgorithm {
  /// EdDSA with Ed25519 curve
  edDSA('EdDSA'),

  /// RSA with SHA-256
  rs256('RS256'),

  /// ECDSA with P-256 curve
  es256('ES256');

  const SignatureAlgorithm(this.name);
  final String name;
}

/// Abstract signer interface
///
/// Implement this interface to provide custom signing logic.
/// This enables:
/// - External key management (IPNS, HSM, Secure Enclave)
/// - Hardware security modules
/// - Multi-signature schemes
/// - Delegated signing
abstract class Signer {
  /// Get the DID of this signer
  DID did();

  /// Get the signature algorithm
  SignatureAlgorithm get algorithm;

  /// Sign a payload
  ///
  /// Returns the signature bytes
  Future<Uint8List> sign(Uint8List payload);

  /// Verify a signature (optional, for testing)
  ///
  /// Returns true if signature is valid
  Future<bool> verify(Uint8List payload, Uint8List signature);

  /// Export signer for persistence (optional)
  ///
  /// Returns null if signer cannot be exported (e.g., HSM)
  Uint8List? export();
}

/// Default Ed25519 signer implementation
///
/// Uses a standard Ed25519 key pair for signing.
class Ed25519Signer implements Signer {
  Ed25519Signer(this.keyPair) : _did = DIDKey.fromKeyPair(keyPair);

  /// Generate a new random Ed25519 signer
  static Future<Ed25519Signer> generate() async {
    final keyPair = await Ed25519KeyPair.generate();
    return Ed25519Signer(keyPair);
  }

  /// Create signer from private key
  static Future<Ed25519Signer> fromPrivateKey(Uint8List privateKey) async {
    final keyPair = await Ed25519KeyPair.fromPrivateKey(privateKey);
    return Ed25519Signer(keyPair);
  }

  /// Import signer from exported bytes
  static Future<Ed25519Signer> import(Uint8List bytes) async {
    // Format: <private-code><private-key><public-code><public-key>
    // We only need the private key to reconstruct everything
    final privateCodeLen = varint.encodingLength(ed25519PrivateCode);
    final privateKey = bytes.sublist(privateCodeLen, privateCodeLen + 32);

    return Ed25519Signer.fromPrivateKey(privateKey);
  }

  /// The Ed25519 key pair
  final Ed25519KeyPair keyPair;

  final DIDKey _did;

  @override
  DID did() => _did;

  @override
  SignatureAlgorithm get algorithm => SignatureAlgorithm.edDSA;

  @override
  Future<Uint8List> sign(Uint8List payload) async => keyPair.sign(payload);

  @override
  Future<bool> verify(Uint8List payload, Uint8List signature) async =>
    keyPair.verify(payload, signature);

  @override
  Uint8List? export() {
    // Format: <private-code><private-key><public-code><public-key>
    // Similar to @ucanto/principal format
    final privateCodeBytes = varint.encode(ed25519PrivateCode);
    final publicCodeBytes = varint.encode(ed25519Code);

    final totalLength = privateCodeBytes.length +
        keyPair.privateKey.length +
        publicCodeBytes.length +
        keyPair.publicKey.length;

    final bytes = Uint8List(totalLength);
    var offset = 0;

    // Private key with code
    bytes.setRange(offset, offset + privateCodeBytes.length, privateCodeBytes);
    offset += privateCodeBytes.length;

    bytes.setRange(
      offset,
      offset + keyPair.privateKey.length,
      keyPair.privateKey,
    );
    offset += keyPair.privateKey.length;

    // Public key with code
    bytes.setRange(offset, offset + publicCodeBytes.length, publicCodeBytes);
    offset += publicCodeBytes.length;

    bytes.setRange(
      offset,
      offset + keyPair.publicKey.length,
      keyPair.publicKey,
    );

    return bytes;
  }

  /// Get the public key bytes
  Uint8List get publicKey => keyPair.publicKey;

  /// Get the private key bytes (secret!)
  Uint8List get privateKey => keyPair.privateKey;
}
