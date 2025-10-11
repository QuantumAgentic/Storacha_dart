/// Ed25519 key pair for digital signatures
///
/// Ed25519 is a high-speed, high-security signature system.
/// Used in Storacha for DID generation and UCAN signing.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Ed25519 key pair (public + private keys)
class Ed25519KeyPair {
  Ed25519KeyPair._({
    required this.publicKey,
    required this.privateKey,
    required SimpleKeyPair keyPair,
  }) : _keyPair = keyPair {
    if (publicKey.length != 32) {
      throw ArgumentError('Ed25519 public key must be 32 bytes');
    }
    if (privateKey.length != 32) {
      throw ArgumentError('Ed25519 private key must be 32 bytes');
    }
  }

  /// Public key (32 bytes)
  final Uint8List publicKey;

  /// Private key (32 bytes, secret!)
  final Uint8List privateKey;

  /// Internal key pair for signing
  final SimpleKeyPair _keyPair;

  /// Generate a new random Ed25519 key pair
  static Future<Ed25519KeyPair> generate() async {
    final ed25519 = Ed25519();
    final keyPair = await ed25519.newKeyPair();

    // Extract keys
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    return Ed25519KeyPair._(
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: Uint8List.fromList(privateKeyBytes),
      keyPair: keyPair,
    );
  }

  /// Derive key pair from an existing private key
  static Future<Ed25519KeyPair> fromPrivateKey(Uint8List privateKey) async {
    if (privateKey.length != 32) {
      throw ArgumentError('Ed25519 private key must be 32 bytes');
    }

    final ed25519 = Ed25519();
    final keyPair = await ed25519.newKeyPairFromSeed(privateKey);

    // Extract public key
    final publicKey = await keyPair.extractPublicKey();

    return Ed25519KeyPair._(
      publicKey: Uint8List.fromList(publicKey.bytes),
      privateKey: privateKey,
      keyPair: keyPair,
    );
  }

  /// Sign data with the private key
  Future<Uint8List> sign(Uint8List data) async {
    final ed25519 = Ed25519();
    final signature = await ed25519.sign(data, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verify signature with the public key
  Future<bool> verify(Uint8List data, Uint8List signature) async {
    try {
      final ed25519 = Ed25519();
      final pubKey = SimplePublicKey(
        publicKey.toList(),
        type: KeyPairType.ed25519,
      );
      final sig = Signature(signature.toList(), publicKey: pubKey);

      return await ed25519.verify(data, signature: sig);
    } catch (e) {
      return false;
    }
  }

  // Needed for value equality testing
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ed25519KeyPair &&
          _bytesEqual(publicKey, other.publicKey) &&
          _bytesEqual(privateKey, other.privateKey);

  // Needed for value equality testing
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => publicKey.length.hashCode ^ privateKey.length.hashCode;

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
