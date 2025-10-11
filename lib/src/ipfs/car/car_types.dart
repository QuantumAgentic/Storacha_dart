import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../multiformats/cid.dart';

/// CAR file version.
enum CARVersion {
  /// CAR version 1.
  v1(1);

  const CARVersion(this.value);

  /// The version number.
  final int value;
}

/// CAR file header.
@immutable
class CARHeader {
  /// Creates a CAR header.
  const CARHeader({
    required this.version,
    required this.roots,
  });

  /// CAR version (usually 1).
  final CARVersion version;

  /// Root CIDs contained in this CAR.
  final List<CID> roots;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CARHeader &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          _listEquals(roots, other.roots);

  @override
  int get hashCode => Object.hash(version, Object.hashAll(roots));

  @override
  String toString() => 'CARHeader(version: $version, roots: $roots)';

  bool _listEquals(List<CID> a, List<CID> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// A CAR file block entry (CID + data).
@immutable
class CARBlock {
  /// Creates a CAR block.
  const CARBlock({
    required this.cid,
    required this.bytes,
  });

  /// The CID of this block.
  final CID cid;

  /// The block data.
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CARBlock &&
          runtimeType == other.runtimeType &&
          cid == other.cid &&
          _bytesEqual(bytes, other.bytes);

  @override
  int get hashCode => Object.hash(cid, Object.hashAll(bytes));

  @override
  String toString() => 'CARBlock(cid: $cid, size: ${bytes.length})';

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

