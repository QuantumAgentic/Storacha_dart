/// Space model for Storacha
///
/// A Space represents a storage namespace with its own DID and capabilities.
library;

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/crypto/signer.dart';

/// A Space in Storacha
///
/// Each space has:
/// - A unique DID (decentralized identifier)
/// - A name (human-readable label)
/// - A signer (for signing UCANs on behalf of the space)
@immutable
class Space {
  const Space({
    required this.did,
    required this.name,
    required this.signer,
    this.createdAt,
  });

  /// Space DID (e.g., "did:key:z6Mkf...")
  final String did;

  /// Human-readable name
  final String name;

  /// Signer for this space
  final Signer signer;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Convert Space to JSON
  Map<String, dynamic> toJson() => {
        'did': did,
        'name': name,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Space && did == other.did && name == other.name;

  @override
  int get hashCode => Object.hash(did, name);

  @override
  String toString() => 'Space(did: $did, name: $name)';
}
