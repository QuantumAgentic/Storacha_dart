/// DID decoder for DAG-CBOR principals
/// 
/// Based on @ipld/dag-ucan/src/did.js
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;
import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';

// Multicodec codes (from @ipld/dag-ucan/src/did.js)
const ED25519 = 0xed;
const RSA = 0x1205;
const P256 = 0x1200;
const P384 = 0x1201;
const P521 = 0x1202;
const SECP256K1 = 0xe7;
const BLS12381G1 = 0xea;
const BLS12381G2 = 0xeb;
const DID_CORE = 0x0d1d;

/// Decode DID from bytes (DAG-CBOR principal encoding)
/// 
/// Reference: @ipld/dag-ucan/src/did.js:decode()
String decodeDid(Uint8List bytes) {
  final (code, _) = varint.decode(bytes);
  
  switch (code) {
    case P256:
      if (bytes.length > 35) {
        throw RangeError('Only p256-pub compressed is supported.');
      }
      // Fall through to DIDKey
      return _encodeDIDKey(bytes);
    
    case ED25519:
    case RSA:
    case P384:
    case P521:
    case BLS12381G1:
    case BLS12381G2:
    case SECP256K1:
      return _encodeDIDKey(bytes);
    
    case DID_CORE:
      return _encodeDIDCore(bytes);
    
    default:
      throw RangeError(
        'Unsupported DID encoding, unknown multicodec 0x${code.toRadixString(16)}.',
      );
  }
}

/// Encode as did:key:...
/// 
/// Reference: @ipld/dag-ucan/src/did.js:DIDKey.did()
String _encodeDIDKey(Uint8List bytes) {
  // Encode bytes as base58btc WITH 'z' prefix
  // Reference: base58btc.encode(this) in JS includes the prefix
  final base58WithPrefix = base58btc.encode(bytes);
  return 'did:key:$base58WithPrefix';
}

/// Encode as did:...
/// 
/// Reference: @ipld/dag-ucan/src/did.js:DID.did()
String _encodeDIDCore(Uint8List bytes) {
  // Skip METHOD_OFFSET bytes (varint encoding of DID_CORE)
  final methodOffset = varint.encodingLength(DID_CORE);
  final suffix = bytes.sublist(methodOffset);
  final didMethod = utf8.decode(suffix);
  return 'did:$didMethod';
}

/// Parse DID string to bytes (inverse of decode)
/// 
/// Reference: @ipld/dag-ucan/src/did.js:parse()
Uint8List parseDid(String did) {
  if (!did.startsWith('did:')) {
    throw RangeError('Invalid DID "$did", must start with "did:"');
  }
  
  if (did.startsWith('did:key:')) {
    // Extract base58btc encoded key (with 'z' prefix)
    final key = did.substring('did:key:'.length);
    return base58btc.decode(key);
  } else {
    // DID_CORE encoding
    final suffix = utf8.encode(did.substring('did:'.length));
    final methodOffset = varint.encodingLength(DID_CORE);
    final result = Uint8List(suffix.length + methodOffset);
    varint.encodeTo(DID_CORE, result, 0);
    result.setRange(methodOffset, result.length, suffix);
    return result;
  }
}

