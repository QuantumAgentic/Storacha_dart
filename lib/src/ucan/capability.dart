/// UCAN Capability representation
///
/// Represents an action (`can`) that a UCAN holder can perform
/// on/with a resource (`with`), optionally with caveats (`nb`).
library;

import 'package:meta/meta.dart';

/// A string that represents some action that a UCAN holder can do.
///
/// Format: `action/subaction` or `*` (wildcard)
/// Examples: `store/add`, `store/remove`, `*`
typedef Ability = String;

/// A string that represents a resource a UCAN holder can act upon.
///
/// Format: `scheme:identifier`
/// Examples: `did:key:z...`, `ipfs://bafybei...`, `mailto:example@example.com`
typedef Resource = String;

/// Represents an ability (`can`) that a UCAN holder can perform
/// with a resource (`with`), optionally with caveats (`nb`).
///
/// Example:
/// ```dart
/// final cap = Capability(
///   with: 'did:key:z6MkhaXg...',
///   can: 'store/add',
///   nb: {'size': 1000000},
/// );
/// ```
// ignore_for_file: sort_constructors_first
@immutable
class Capability {
  const Capability({
    required this.with_,
    required this.can,
    this.nb,
  });

  /// Create from JSON
  factory Capability.fromJson(Map<String, dynamic> json) => Capability(
        with_: json['with'] as String,
        can: json['can'] as String,
        nb: json['nb'] as Map<String, dynamic>?,
      );

  /// The resource this capability applies to
  final Resource with_;

  /// The ability/action this capability grants
  final Ability can;

  /// Optional caveats/constraints on this capability
  ///
  /// Common caveats:
  /// - `size`: maximum size in bytes
  /// - `space`: space DID
  /// - `link`: CID of content
  final Map<String, dynamic>? nb;

  /// Convert to JSON
  ///
  /// IMPORTANT: This preserves CID objects in nb for proper DAG-CBOR encoding.
  /// CIDs will be encoded with CBOR tag 42 by the DAG-CBOR encoder.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'with': with_,
      'can': can,
    };

    if (nb != null && nb!.isNotEmpty) {
      // Preserve CID objects - don't call toJson() on them
      // The DAG-CBOR encoder will handle them correctly
      json['nb'] = nb;
    }

    return json;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Capability &&
          with_ == other.with_ &&
          can == other.can &&
          _mapsEqual(nb, other.nb);

  @override
  int get hashCode => Object.hash(with_, can, nb);

  bool _mapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    final nbPart = nb != null ? ', nb: $nb' : '';
    return 'Capability(with: $with_, can: $can$nbPart)';
  }
}

/// Helper to build a ucan/conclude invocation payload equivalent
Capability buildConcludeCapability({
  required String withDid,
  required Map<String, dynamic> receiptCbor,
}) {
  // Encode receipt DAG-CBOR like JS does: attach receipt as root in facts
  // We place a placeholder here since our transport leverages IPLDInvocationBuilder
  return Capability(
    with_: withDid,
    can: 'ucan/conclude',
    nb: {
      'receipt': receiptCbor,
    },
  );
}
