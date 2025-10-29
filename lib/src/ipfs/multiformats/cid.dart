/// Content Identifier (CID) implementation
///
/// Self-describing content-addressed identifier for distributed systems.
/// Based on multiformats CID specification.
// ignore_for_file: sort_constructors_first
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Multicodec codes
const int dagPbCode = 0x70; // dag-pb
const int rawCode = 0x55; // raw binary
const int carCode = 0x202; // CAR file
const int dagCborCode = 0x71; // dag-cbor
const int dagJsonCode = 0x0129; // dag-json

/// CID version type
enum CidVersion {
  /// CIDv0 - dag-pb + SHA-256 only, base58btc encoded
  v0(0),

  /// CIDv1 - any codec + any hash, multibase encoded
  v1(1);

  const CidVersion(this.value);
  final int value;

  static CidVersion fromInt(int value) {
    switch (value) {
      case 0:
        return CidVersion.v0;
      case 1:
        return CidVersion.v1;
      default:
        throw ArgumentError('Invalid CID version: $value');
    }
  }
}

/// Content Identifier (CID)
///
/// A self-describing content-addressed identifier that includes:
/// - Version (0 or 1)
/// - Codec (content encoding format)
/// - Multihash (cryptographic hash of content)
@immutable
final class CID {
  // ignore: prefer_const_constructors_in_immutables
  CID._({
    required this.version,
    required this.code,
    required this.multihash,
    required this.bytes,
  });

  /// CID version (0 or 1)
  final CidVersion version;

  /// Codec code (e.g., 0x70 for dag-pb)
  final int code;

  /// Multihash of the content
  final MultihashDigest multihash;

  /// Binary representation of the CID
  final Uint8List bytes;

  /// Create a CIDv0 (dag-pb + SHA-256 only)
  factory CID.createV0(MultihashDigest multihash) => CID.create(
        version: CidVersion.v0,
        code: dagPbCode,
        multihash: multihash,
      );

  /// Create a CIDv1 (any codec + any hash)
  factory CID.createV1(int code, MultihashDigest multihash) => CID.create(
        version: CidVersion.v1,
        code: code,
        multihash: multihash,
      );

  /// Create a CID from components
  ///
  /// For CIDv0: only dag-pb (0x70) and SHA-256 are allowed
  /// For CIDv1: any codec and hash algorithm
  factory CID.create({
    required CidVersion version,
    required int code,
    required MultihashDigest multihash,
  }) {
    if (multihash.digest.isEmpty) {
      throw ArgumentError('Invalid digest');
    }

    switch (version) {
      case CidVersion.v0:
        if (code != dagPbCode) {
          throw ArgumentError(
            'Version 0 CID must use dag-pb (code: $dagPbCode)',
          );
        }
        if (multihash.code != 0x12) {
          // SHA-256
          throw ArgumentError(
            'Version 0 CID must use SHA-256 (code: 0x12)',
          );
        }
        // CIDv0 is just the multihash bytes
        return CID._(
          version: version,
          code: code,
          multihash: multihash,
          bytes: multihash.bytes,
        );

      case CidVersion.v1:
        // CIDv1: <version><codec><multihash>
        final bytes = _encodeCidV1(code, multihash.bytes);
        return CID._(
          version: version,
          code: code,
          multihash: multihash,
          bytes: bytes,
        );
    }
  }

  /// Decode a CID from bytes
  factory CID.decode(Uint8List bytes) {
    final result = CID.decodeFirst(bytes);
    if (result.$2.isNotEmpty) {
      throw ArgumentError('Incorrect length: extra bytes after CID');
    }
    return result.$1;
  }

  /// Parse a CID from string representation
  factory CID.parse(String source) {
    // CIDv0 starts with 'Q'
    if (source.startsWith('Q')) {
      // CIDv0 is base58btc without prefix
      final bytes = base58btc.decodeRaw(source);
      return CID.decode(bytes);
    }

    // CIDv1 has multibase prefix
    if (source.isEmpty) {
      throw ArgumentError('Cannot parse empty string as CID');
    }

    // Decode with multibase (auto-detect from prefix)
    final bytes = multibaseDecode(source);
    final cid = CID.decode(bytes);

    // Validate
    if (cid.version == CidVersion.v0) {
      throw ArgumentError(
        'Version 0 CID string must not include multibase prefix',
      );
    }

    return cid;
  }

  /// Decode a CID from bytes, returning CID and remaining bytes
  ///
  /// Note: Analyzer suggests making this a constructor, but it's a static
  /// factory that returns a tuple, not a single instance.
  // ignore: prefer_constructors_over_static_methods
  static (CID, Uint8List) decodeFirst(Uint8List bytes) {
    final specs = _inspectBytes(bytes);

    // Extract multihash
    final prefixSize = specs.size - specs.multihashSize;
    final multihashBytes = bytes.sublist(
      prefixSize,
      prefixSize + specs.multihashSize,
    );

    if (multihashBytes.length != specs.multihashSize) {
      throw ArgumentError('Incorrect length: multihash truncated');
    }

    final multihash = decodeMultihash(multihashBytes);

    // Create CID
    final cid = specs.version == CidVersion.v0
        ? CID.createV0(multihash)
        : CID.createV1(specs.codec, multihash);

    final remainder = bytes.sublist(specs.size);
    return (cid, remainder);
  }

  /// Parse from JSON representation
  ///
  /// Note: Analyzer suggests making this a constructor, but named constructors
  /// can't be used with Map<String, dynamic> parameter type.
  // ignore: prefer_constructors_over_static_methods
  static CID fromJson(Map<String, dynamic> json) {
    final link = json['/'];
    if (link == null || link is! String) {
      throw ArgumentError('Invalid CID JSON: missing or invalid "/" field');
    }
    return CID.parse(link);
  }


  /// Convert to CIDv0
  ///
  /// Only works if this is dag-pb + SHA-256
  CID toV0() {
    switch (version) {
      case CidVersion.v0:
        return this;
      case CidVersion.v1:
        if (code != dagPbCode) {
          throw StateError('Cannot convert non dag-pb CID to CIDv0');
        }
        if (multihash.code != 0x12) {
          // SHA-256
          throw StateError('Cannot convert non SHA-256 CID to CIDv0');
        }
        return CID.createV0(multihash);
    }
  }

  /// Convert to CIDv1
  CID toV1() {
    switch (version) {
      case CidVersion.v0:
        return CID.createV1(code, multihash);
      case CidVersion.v1:
        return this;
    }
  }

  /// Convert to JSON (for DAG-CBOR encoding)
  /// NOTE: This is called during JSON serialization
  /// 🐛 DEBUG: Added logging to track when this is called
  Map<String, String> toJson() {
    print('🐛 [CID.toJson()] WARNING: toJson() called on CID!');
    print('🐛   CID: ${toString()}');
    print('🐛   Codec: $code (0x${code.toRadixString(16)})');
    print('🐛   StackTrace: ${StackTrace.current}');
    return {'/': toString()};
  }

  /// Encode to string with optional base encoder
  ///
  /// CIDv0: always base58btc without prefix
  /// CIDv1: multibase with prefix (default: base32)
  @override
  String toString([MultibaseCodec? base]) {
    switch (version) {
      case CidVersion.v0:
        // CIDv0 is always base58btc without prefix
        return base58btc.encodeRaw(bytes);

      case CidVersion.v1:
        // CIDv1 uses multibase with prefix
        final codec = base ?? base32;
        return codec.encode(bytes);
    }
  }

  /// Check equality with another CID
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CID &&
          version == other.version &&
          code == other.code &&
          _bytesEqual(bytes, other.bytes);

  @override
  int get hashCode => version.hashCode ^ code.hashCode ^ bytes.length.hashCode;

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

  // toJson() method is defined earlier in the file with debug logging
}

/// Encode CIDv1 bytes: <version><codec><multihash>
Uint8List _encodeCidV1(int codec, Uint8List multihashBytes) {
  final versionBytes = varint.encode(1);
  final codecBytes = varint.encode(codec);

  final totalLength =
      versionBytes.length + codecBytes.length + multihashBytes.length;
  final result = Uint8List(totalLength);

  var offset = 0;
  result.setRange(offset, offset + versionBytes.length, versionBytes);
  offset += versionBytes.length;

  result.setRange(offset, offset + codecBytes.length, codecBytes);
  offset += codecBytes.length;

  result.setRange(offset, offset + multihashBytes.length, multihashBytes);

  return result;
}

/// Inspect bytes to extract CID metadata
({
  CidVersion version,
  int codec,
  int multihashCode,
  int digestSize,
  int multihashSize,
  int size,
}) _inspectBytes(Uint8List bytes) {
  var offset = 0;

  int readVarint() {
    final result = varint.decode(bytes.sublist(offset));
    offset += result.$2;
    return result.$1;
  }

  var versionValue = readVarint();
  var codec = dagPbCode;

  // Check if this is CIDv0 (starts with 0x12 which is SHA-256 code)
  if (versionValue == 0x12) {
    // This is CIDv0, reset and treat as multihash
    offset = 0;
    versionValue = 0;
  } else {
    // This is CIDv1, read codec
    codec = readVarint();
  }

  final version = CidVersion.fromInt(versionValue);

  final prefixSize = offset;
  final multihashCode = readVarint();
  final digestSize = readVarint();
  final size = offset + digestSize;
  final multihashSize = size - prefixSize;

  return (
    version: version,
    codec: codec,
    multihashCode: multihashCode,
    digestSize: digestSize,
    multihashSize: multihashSize,
    size: size,
  );
}
