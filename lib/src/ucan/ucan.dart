/// UCAN (User Controlled Authorization Network) implementation
///
/// UCANs are JWT-like tokens for decentralized authorization.
/// Based on https://github.com/ucan-wg/spec
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';
import 'package:storacha_dart/src/ucan/capability.dart';

/// UCAN version string (semantic versioning)
typedef UCANVersion = String;

/// UTC Unix timestamp (seconds since epoch)
typedef UTCUnixTimestamp = int;

/// Nonce string for uniqueness
typedef Nonce = String;

/// Verifiable facts included in a UCAN to support claimed capabilities
typedef Fact = Map<String, dynamic>;

/// UCAN Header (JWT format)
// ignore_for_file: sort_constructors_first
@immutable
class UCANHeader {
  const UCANHeader({
    required this.version,
    required this.algorithm,
    this.type = 'JWT',
  });

  /// Create from JSON
  factory UCANHeader.fromJson(Map<String, dynamic> json) => UCANHeader(
        version: json['ucv'] as String,
        algorithm: json['alg'] as String,
        type: json['typ'] as String? ?? 'JWT',
      );

  /// UCAN spec version (e.g., "0.10.0")
  final UCANVersion version;

  /// Signature algorithm (e.g., "EdDSA", "RS256")
  final String algorithm;

  /// Token type (always "JWT")
  final String type;

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'ucv': version,
        'alg': algorithm,
        'typ': type,
      };

  /// Encode as base64url
  String encode() {
    final jsonBytes = utf8.encode(jsonEncode(toJson()));
    return base64url.encode(Uint8List.fromList(jsonBytes));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UCANHeader &&
          version == other.version &&
          algorithm == other.algorithm &&
          type == other.type;

  @override
  int get hashCode => Object.hash(version, algorithm, type);
}

/// UCAN Payload (JWT format)
@immutable
class UCANPayload {
  const UCANPayload({
    required this.issuer,
    required this.audience,
    required this.capabilities,
    required this.expiration,
    this.notBefore,
    this.nonce,
    this.facts = const [],
    this.proofs = const [],
  });

  /// Issuer DID (who issued this UCAN)
  final String issuer;

  /// Audience DID (who can use this UCAN)
  final String audience;

  /// List of capabilities granted by this UCAN
  final List<Capability> capabilities;

  /// Expiration timestamp (null = never expires)
  final UTCUnixTimestamp? expiration;

  /// Not valid before timestamp
  final UTCUnixTimestamp? notBefore;

  /// Nonce for uniqueness
  final Nonce? nonce;

  /// Verifiable facts to support capabilities
  final List<Fact> facts;

  /// Proofs (CIDs of parent UCANs)
  final List<CID> proofs;

  /// Create from JSON
  factory UCANPayload.fromJson(Map<String, dynamic> json) => UCANPayload(
        issuer: json['iss'] as String,
        audience: json['aud'] as String,
        capabilities: (json['att'] as List)
            .map((c) => Capability.fromJson(c as Map<String, dynamic>))
            .toList(),
        expiration: json['exp'] as int?,
        notBefore: json['nbf'] as int?,
        nonce: json['nnc'] as String?,
        facts: (json['fct'] as List?)
                ?.map((f) => f as Map<String, dynamic>)
                .toList() ??
            [],
        proofs: (json['prf'] as List?)
                ?.map((p) => CID.parse(p as String))
                .toList() ??
            [],
      );

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'iss': issuer,
      'aud': audience,
      'att': capabilities.map((c) => c.toJson()).toList(),
      'exp': expiration,
    };

    if (notBefore != null) {
      json['nbf'] = notBefore;
    }
    if (nonce != null) {
      json['nnc'] = nonce;
    }
    if (facts.isNotEmpty) {
      json['fct'] = facts;
    }
    if (proofs.isNotEmpty) {
      json['prf'] = proofs.map((p) => p.toString()).toList();
    }

    return json;
  }

  /// Encode as base64url
  String encode() {
    final jsonBytes = utf8.encode(jsonEncode(toJson()));
    return base64url.encode(Uint8List.fromList(jsonBytes));
  }

  /// Check if this UCAN is expired
  bool isExpired([DateTime? now]) {
    if (expiration == null) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    final expirationTime =
        DateTime.fromMillisecondsSinceEpoch(expiration! * 1000, isUtc: true);
    return currentTime.isAfter(expirationTime);
  }

  /// Check if this UCAN is not yet valid
  bool isNotYetValid([DateTime? now]) {
    if (notBefore == null) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    final notBeforeTime =
        DateTime.fromMillisecondsSinceEpoch(notBefore! * 1000, isUtc: true);
    return currentTime.isBefore(notBeforeTime);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UCANPayload &&
          issuer == other.issuer &&
          audience == other.audience &&
          expiration == other.expiration &&
          notBefore == other.notBefore &&
          nonce == other.nonce &&
          _listsEqual(capabilities, other.capabilities) &&
          _listsEqual(facts, other.facts) &&
          _listsEqual(proofs, other.proofs);

  @override
  int get hashCode => Object.hash(
        issuer,
        audience,
        expiration,
        notBefore,
        nonce,
        Object.hashAll(capabilities),
        Object.hashAll(facts),
        Object.hashAll(proofs),
      );

  bool _listsEqual<T>(List<T> a, List<T> b) {
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

/// UCAN (User Controlled Authorization Network) token
@immutable
class UCAN {
  const UCAN({
    required this.header,
    required this.payload,
    required this.signature,
  });

  /// UCAN header
  final UCANHeader header;

  /// UCAN payload
  final UCANPayload payload;

  /// Signature bytes
  final Uint8List signature;

  /// Create a new UCAN by signing
  static Future<UCAN> create({
    required Signer issuer,
    required String audience,
    required List<Capability> capabilities,
    int? lifetimeInSeconds,
    UTCUnixTimestamp? expiration,
    UTCUnixTimestamp? notBefore,
    Nonce? nonce,
    List<Fact>? facts,
    List<CID>? proofs,
    String version = '0.10.0',
  }) async {
    // Calculate expiration
    final exp = expiration ??
        (lifetimeInSeconds != null
            ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) +
                lifetimeInSeconds
            : null);

    // Create header
    final header = UCANHeader(
      version: version,
      algorithm: issuer.algorithm.name,
    );

    // Create payload
    final payload = UCANPayload(
      issuer: issuer.did().did(),
      audience: audience,
      capabilities: capabilities,
      expiration: exp,
      notBefore: notBefore,
      nonce: nonce,
      facts: facts ?? [],
      proofs: proofs ?? [],
    );

    // Sign: header.payload
    final signingInput = '${header.encode()}.${payload.encode()}';
    final signingBytes = utf8.encode(signingInput);
    final signature = await issuer.sign(Uint8List.fromList(signingBytes));

    return UCAN(
      header: header,
      payload: payload,
      signature: signature,
    );
  }

  /// Parse UCAN from JWT string (header.payload.signature)
  factory UCAN.parse(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      throw ArgumentError('Invalid JWT format: expected 3 parts');
    }

    // Decode header
    final headerBytes = base64url.decode(parts[0]);
    final headerJson =
        jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
    final header = UCANHeader.fromJson(headerJson);

    // Decode payload
    final payloadBytes = base64url.decode(parts[1]);
    final payloadJson =
        jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
    final payload = UCANPayload.fromJson(payloadJson);

    // Decode signature
    final signature = base64url.decode(parts[2]);

    return UCAN(
      header: header,
      payload: payload,
      signature: signature,
    );
  }

  /// Encode UCAN as JWT string
  String encode() {
    final encodedSignature =
        base64url.encode(Uint8List.fromList(signature.toList()));
    return '${header.encode()}.${payload.encode()}.$encodedSignature';
  }

  /// Verify signature
  Future<bool> verify(Signer signer) async {
    final signingInput = '${header.encode()}.${payload.encode()}';
    final signingBytes = utf8.encode(signingInput);
    return signer.verify(Uint8List.fromList(signingBytes), signature);
  }

  /// Check if this UCAN is expired
  bool get isExpired => payload.isExpired();

  /// Check if this UCAN is not yet valid
  bool get isNotYetValid => payload.isNotYetValid();

  /// Check if this UCAN is currently valid (time-wise)
  bool get isValid => !isExpired && !isNotYetValid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UCAN &&
          header == other.header &&
          payload == other.payload &&
          _bytesEqual(signature, other.signature);

  @override
  int get hashCode => Object.hash(header, payload, signature.length);

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

  @override
  String toString() => encode();
}
