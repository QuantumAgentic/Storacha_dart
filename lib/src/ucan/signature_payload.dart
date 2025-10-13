/// Signature payload encoding for UCAN
///
/// The signature in a UCAN is calculated over a JWT-style string:
/// `header.payload` where both header and payload are base64url-encoded JSON.
///
/// Reference: @ipld/dag-ucan/src/formatter.js
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';

/// Base64url encode without padding
String _base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Encode the signature payload as JWT-style string
///
/// This creates `header.payload` where:
/// - header = base64url(JSON.encode({"alg":"EdDSA","ucv":"0.9.1","typ":"JWT"}))
/// - payload = base64url(JSON.encode({iss, aud, att, exp, ...}))
///
/// The signature is then calculated over UTF-8 bytes of this string.
Uint8List encodeSignaturePayload({
  required String issuer,
  required String audience,
  required List<Capability> capabilities,
  required int expiration,
  required List<CID> proofs,
  int? notBefore,
  String? nonce,
  List<Map<String, dynamic>> facts = const [],
  String version = '0.9.1',
  String algorithm = 'EdDSA',
}) {
  // 1. Encode header: {"alg":"EdDSA","typ":"JWT","ucv":"0.9.1"}
  // IMPORTANT: Keys must be in alphabetical order like @ipld/dag-json
  final headerMap = {
    'alg': algorithm,  // a
    'typ': 'JWT',      // t
    'ucv': version,    // u
  };
  final headerJson = _encodeJsonCanonical(headerMap);
  final headerBytes = utf8.encode(headerJson);
  final headerB64 = _base64UrlEncode(headerBytes);

  // 2. Encode payload
  final payloadMap = <String, dynamic>{
    'iss': issuer, // DID string (e.g., "did:key:z6Mk...")
    'aud': audience, // DID string
    'att': capabilities.map((c) => c.toJson()).toList(),
    'exp': expiration,
    'prf': proofs.map((cid) => cid.toString()).toList(),
  };

  // Add optional fields
  if (facts.isNotEmpty) {
    payloadMap['fct'] = facts;
  }
  if (nonce != null) {
    payloadMap['nnc'] = nonce;
  }
  if (notBefore != null) {
    payloadMap['nbf'] = notBefore;
  }

  final payloadJson = _encodeJsonCanonical(payloadMap);
  final payloadBytes = utf8.encode(payloadJson);
  final payloadB64 = _base64UrlEncode(payloadBytes);

  // 3. Concatenate header.payload
  final signPayload = '$headerB64.$payloadB64';

  // 4. Return UTF-8 bytes
  return Uint8List.fromList(utf8.encode(signPayload));
}

/// Encode JSON with keys in alphabetical order (canonical form)
/// This matches @ipld/dag-json behavior
String _encodeJsonCanonical(Map<String, dynamic> map) {
  final sortedKeys = map.keys.toList()..sort();
  final buffer = StringBuffer('{');
  
  for (var i = 0; i < sortedKeys.length; i++) {
    if (i > 0) buffer.write(',');
    final key = sortedKeys[i];
    final value = map[key];
    
    buffer.write(json.encode(key));
    buffer.write(':');
    buffer.write(_encodeJsonValue(value));
  }
  
  buffer.write('}');
  return buffer.toString();
}

/// Encode a JSON value recursively with canonical ordering
/// This matches @ipld/dag-json behavior where Uint8List is encoded as IPLD bytes object
String _encodeJsonValue(dynamic value) {
  if (value is Map) {
    return _encodeJsonCanonical(value.cast<String, dynamic>());
  } else if (value is Uint8List) {
    // Encode as IPLD bytes object: {"/": {"bytes": "base64"}}
    // This matches the @ucanto/core signature payload encoding
    // Use standard base64 encoding WITHOUT padding (not base64url!)
    final base64Str = base64.encode(value).replaceAll('=', '');
    return '{"/":{"bytes":"$base64Str"}}';
  } else if (value is List<int>) {
    // Also handle List<int> as IPLD bytes
    // Use standard base64 encoding WITHOUT padding (not base64url!)
    final base64Str = base64.encode(value).replaceAll('=', '');
    return '{"/":{"bytes":"$base64Str"}}';
  } else if (value is List) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(_encodeJsonValue(value[i]));
    }
    buffer.write(']');
    return buffer.toString();
  } else {
    return json.encode(value);
  }
}

