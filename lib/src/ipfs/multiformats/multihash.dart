/// Multihash implementation
///
/// Self-describing hash format for content addressing.
/// Format: <hash-code><digest-size><digest-bytes>
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:storacha_dart/src/ipfs/multiformats/varint.dart' as varint;

/// Represents a multihash digest
///
/// Contains the hash algorithm code, size, the digest bytes,
/// and the full encoded multihash bytes.
@immutable
final class MultihashDigest {
  // ignore: prefer_const_constructors_in_immutables
  MultihashDigest({
    required this.code,
    required this.size,
    required this.digest,
    required this.bytes,
  });

  /// Hash algorithm code (e.g., 0x12 for SHA-256)
  final int code;

  /// Size of the digest in bytes
  final int size;

  /// The actual hash digest
  final Uint8List digest;

  /// The complete multihash bytes (code + size + digest)
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultihashDigest &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          size == other.size &&
          _bytesEqual(bytes, other.bytes);

  @override
  int get hashCode => code.hashCode ^ size.hashCode ^ bytes.length.hashCode;

  @override
  String toString() => 'MultihashDigest(code: 0x${code.toRadixString(16)}, '
      'size: $size)';

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

/// Creates a multihash digest from code and digest bytes
MultihashDigest createMultihash(int code, Uint8List digest) {
  final size = digest.lengthInBytes;
  final sizeOffset = varint.encodingLength(code);
  final digestOffset = sizeOffset + varint.encodingLength(size);

  final bytes = Uint8List(digestOffset + size);
  varint.encodeTo(code, bytes);
  varint.encodeTo(size, bytes, sizeOffset);
  bytes.setRange(digestOffset, digestOffset + size, digest);

  return MultihashDigest(
    code: code,
    size: size,
    digest: digest,
    bytes: bytes,
  );
}

/// Decodes a multihash from bytes
MultihashDigest decodeMultihash(Uint8List multihash) {
  final codeResult = varint.decode(multihash);
  final code = codeResult.$1;
  final sizeOffset = codeResult.$2;

  final sizeResult = varint.decode(multihash.sublist(sizeOffset));
  final size = sizeResult.$1;
  final digestOffset = sizeResult.$2;

  final digest = multihash.sublist(
    sizeOffset + digestOffset,
    sizeOffset + digestOffset + size,
  );

  if (digest.lengthInBytes != size) {
    throw ArgumentError(
      'Incorrect digest length: expected $size, got ${digest.lengthInBytes}',
    );
  }

  return MultihashDigest(
    code: code,
    size: size,
    digest: digest,
    bytes: multihash,
  );
}

/// Options for digest creation
class DigestOptions {
  const DigestOptions({this.truncate});

  /// Truncate the digest to this number of bytes
  final int? truncate;
}

/// Abstract hasher interface
abstract class Hasher {
  /// Algorithm name (e.g., 'sha2-256')
  String get name;

  /// Multihash code (e.g., 0x12 for SHA-256)
  int get code;

  /// Minimum allowed digest length in bytes
  int get minDigestLength => 20;

  /// Maximum allowed digest length in bytes (null = no limit)
  int? get maxDigestLength => null;

  /// Encode input data to hash digest
  Uint8List encode(Uint8List input);

  /// Create a multihash digest from input data
  MultihashDigest digest(Uint8List input, [DigestOptions? options]) {
    // Validate truncate option
    if (options?.truncate != null) {
      if (options!.truncate! < minDigestLength) {
        throw ArgumentError(
          'Invalid truncate option, must be >= $minDigestLength',
        );
      }

      if (maxDigestLength != null && options.truncate! > maxDigestLength!) {
        throw ArgumentError(
          'Invalid truncate option, must be <= $maxDigestLength',
        );
      }
    }

    // Generate hash
    var hashDigest = encode(input);

    // Apply truncation if requested
    if (options?.truncate != null && options!.truncate != hashDigest.length) {
      if (options.truncate! > hashDigest.length) {
        throw ArgumentError(
          'Invalid truncate option, must be <= ${hashDigest.length}',
        );
      }
      hashDigest = hashDigest.sublist(0, options.truncate);
    }

    return createMultihash(code, hashDigest);
  }
}

/// SHA-256 hasher
class Sha256Hasher extends Hasher {
  @override
  String get name => 'sha2-256';

  @override
  int get code => 0x12;

  @override
  int get maxDigestLength => 32;

  @override
  Uint8List encode(Uint8List input) =>
      Uint8List.fromList(sha256.convert(input).bytes);
}

/// SHA-512 hasher
class Sha512Hasher extends Hasher {
  @override
  String get name => 'sha2-512';

  @override
  int get code => 0x13;

  @override
  int get maxDigestLength => 64;

  @override
  Uint8List encode(Uint8List input) =>
      Uint8List.fromList(sha512.convert(input).bytes);
}

/// Identity hasher (no hashing, returns input as-is)
///
/// Used when the content is already small or unique enough
class IdentityHasher extends Hasher {
  @override
  String get name => 'identity';

  @override
  int get code => 0x00;

  @override
  int get minDigestLength => 0;

  @override
  Uint8List encode(Uint8List input) => input;
}

// Global hasher instances
final sha256Hasher = Sha256Hasher();
final sha512Hasher = Sha512Hasher();
final identityHasher = IdentityHasher();

// Hasher registry
final _hashers = <int, Hasher>{
  0x00: identityHasher, // identity
  0x12: sha256Hasher, // sha2-256
  0x13: sha512Hasher, // sha2-512
};

/// Get hasher by code
Hasher? getHasher(int code) => _hashers[code];

/// Check if hasher code is supported
bool isHasherSupported(int code) => _hashers.containsKey(code);

/// Hash input with SHA-256 and return multihash
MultihashDigest sha256Hash(Uint8List input, [DigestOptions? options]) =>
    sha256Hasher.digest(input, options);

/// Hash input with SHA-512 and return multihash
MultihashDigest sha512Hash(Uint8List input, [DigestOptions? options]) =>
    sha512Hasher.digest(input, options);

/// Check if multihash has specific code
bool hasCode(MultihashDigest digest, int code) => digest.code == code;
