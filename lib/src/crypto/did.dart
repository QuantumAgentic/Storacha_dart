/// Decentralized Identifier (DID) implementation
///
/// Based on W3C DID specification and did:key method.
/// Used for identifying agents, spaces, and signing UCANs.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/crypto/ed25519_key_pair.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Multicodec codes for different key types
const int ed25519Code = 0xed; // Ed25519 public key
const int ed25519PrivateCode = 0x1300; // Ed25519 private key
const int rsaCode = 0x1205; // RSA
const int p256Code = 0x1200; // P-256
const int secp256k1Code = 0xe7; // secp256k1

/// DID (Decentralized Identifier)
///
/// Abstract representation of a DID that can be formatted as a string.
abstract class DID {
  /// Parse a DID string
  factory DID.parse(String did) {
    if (!did.startsWith('did:')) {
      throw ArgumentError('Invalid DID: must start with "did:"');
    }

    if (did.startsWith('did:key:')) {
      return DIDKey.parse(did);
    }

    throw ArgumentError('Unsupported DID method: only did:key is supported');
  }

  /// Get DID as string (e.g., "did:key:z...")
  String did();

  /// Get bytes representation
  Uint8List bytes();
}

/// DID using the did:key method with Ed25519
///
/// Format: did:key:z<base58btc-encoded-multicodec-public-key>
// ignore_for_file: sort_constructors_first
@immutable
class DIDKey implements DID {
  const DIDKey._(this._bytes);

  final Uint8List _bytes;

  /// Create DIDKey from Ed25519 public key
  factory DIDKey.fromPublicKey(Uint8List publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError('Ed25519 public key must be 32 bytes');
    }

    // Encode public key with Ed25519 multicodec prefix (0xed)
    final codecBytes = varint.encode(ed25519Code);
    final bytes = Uint8List(codecBytes.length + publicKey.length)
      ..setRange(0, codecBytes.length, codecBytes)
      ..setRange(
        codecBytes.length,
        codecBytes.length + publicKey.length,
        publicKey,
      );

    return DIDKey._(bytes);
  }

  /// Parse a did:key string
  factory DIDKey.parse(String did) {
    if (!did.startsWith('did:key:')) {
      throw ArgumentError('Invalid did:key: must start with "did:key:"');
    }

    // Remove "did:key:" prefix and decode base58btc
    final encoded = did.substring(8);
    if (!encoded.startsWith('z')) {
      throw ArgumentError('did:key must use base58btc encoding (prefix z)');
    }

    final bytes = base58btc.decode(encoded);

    // Verify multicodec
    final codecResult = varint.decode(bytes);
    final code = codecResult.$1;

    if (code != ed25519Code) {
      throw ArgumentError(
        'Unsupported key type: 0x${code.toRadixString(16)}. '
        'Only Ed25519 (0xed) is currently supported.',
      );
    }

    return DIDKey._(bytes);
  }

  /// Create DIDKey from Ed25519KeyPair
  factory DIDKey.fromKeyPair(Ed25519KeyPair keyPair) =>
    DIDKey.fromPublicKey(keyPair.publicKey);

  @override
  Uint8List bytes() => _bytes;

  /// Get raw public key (without multicodec prefix)
  Uint8List get publicKey {
    final codecResult = varint.decode(_bytes);
    final offset = codecResult.$2;
    return _bytes.sublist(offset);
  }

  /// Get multicodec code
  int get code {
    final codecResult = varint.decode(_bytes);
    return codecResult.$1;
  }

  @override
  String did() {
    // Encode bytes as base58btc and add did:key: prefix
    final encoded = base58btc.encode(_bytes);
    return 'did:key:$encoded';
  }

  @override
  String toString() => did();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DIDKey && _bytesEqual(_bytes, other._bytes);

  @override
  int get hashCode => _bytes.length.hashCode;

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
