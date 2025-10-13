/// UCAN Delegation support for loading and managing delegated capabilities
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:storacha_dart/src/ipfs/car/car_reader.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/ucan.dart';
import 'package:storacha_dart/src/ucan/ucan_dag_cbor.dart';

/// Represents a UCAN delegation that grants capabilities
/// 
/// A delegation is a UCAN token that authorizes an agent (audience)
/// to perform actions on behalf of another agent (issuer).
/// 
/// Example usage:
/// ```dart
/// // Load delegation from file created by Storacha CLI
/// final delegation = await Delegation.fromFile('proof.ucan');
/// 
/// // Or parse from JWT string
/// final delegation = Delegation.fromToken(jwtString);
/// 
/// // Use with client
/// final client = StorachaClient(
///   config,
///   delegations: [delegation],
/// );
/// ```
@immutable
class Delegation {
  const Delegation({
    required this.ucan,
    this.archive,
    this.ucanCid,
  });

  /// The UCAN token representing this delegation
  final UCAN ucan;

  /// Optional CAR archive containing proof chain
  /// This is used when the delegation includes references to parent UCANs
  final Uint8List? archive;

  /// Optional: the CID of the UCAN block (for proof references in invocations)
  /// When a delegation is loaded from a CAR file with a variant root, this stores
  /// the CID of the actual UCAN block (not the variant root)
  final CID? ucanCid;

  /// Parse delegation from a JWT token string
  factory Delegation.fromToken(String token) {
    final ucan = UCAN.parse(token);
    return Delegation(ucan: ucan);
  }

  /// Parse delegation from identity CID string (Storacha CLI --base64 format)
  /// 
  /// When you use `storacha delegation create --base64`, it outputs an
  /// identity CID in base64 multibase format (starting with 'm').
  /// The CID contains the actual CAR data in its digest.
  /// 
  /// Format: m<base64-encoded-identity-cid>
  /// 
  /// Example:
  /// ```dart
  /// final delegation = Delegation.fromIdentityCid(identityCidString);
  /// ```
  factory Delegation.fromIdentityCid(String identityCid) {
    try {
      // Remove multibase prefix if present
      var base64Content = identityCid;
      if (identityCid.startsWith('m')) {
        base64Content = identityCid.substring(1);
      } else if (identityCid.startsWith('b') || identityCid.startsWith('u')) {
        throw FormatException(
          'Unsupported multibase prefix: ${identityCid[0]}. '
          'Only "m" (base64) is currently supported for identity CIDs.',
        );
      }
      
      // Add base64 padding if needed
      while (base64Content.length % 4 != 0) {
        base64Content += '=';
      }
      
      // Decode base64 to get CID bytes
      final cidBytes = base64.decode(base64Content);
      
      // Decode CID
      final cid = CID.decode(cidBytes);
      
      // Verify it's an identity CID (hash code = 0)
      if (cid.multihash.code != 0) {
        throw FormatException(
          'Not an identity CID: hash code is ${cid.multihash.code}, expected 0',
        );
      }
      
      // Verify it's a CAR codec (0x0202 = 514)
      if (cid.code != 0x0202) {
        throw FormatException(
          'Not a CAR CID: codec is ${cid.code}, expected 514 (0x0202)',
        );
      }
      
      // Extract CAR data from the identity hash digest
      final carBytes = cid.multihash.digest;
      
      // Parse as CAR
      return Delegation.fromCarBytes(carBytes);
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to parse identity CID: $e');
    }
  }

  /// Load delegation from a file
  /// 
  /// Supports two Storacha CLI delegation formats:
  /// 
  /// 1. **Without `--base64`**: Binary CAR file (simplest format)
  ///    ```bash
  ///    storacha delegation create <did> -c space/blob/add -o delegation.car
  ///    ```
  /// 
  /// 2. **With `--base64`**: Identity CID format (for environment variables)
  ///    ```bash
  ///    storacha delegation create <did> -c space/blob/add --base64 > delegation.txt
  ///    ```
  /// 
  /// Throws [FileSystemException] if file cannot be read.
  /// Throws [FormatException] if content is not valid.
  static Future<Delegation> fromFile(String path) async {
    final file = File(path);
    
    if (!await file.exists()) {
      throw FileSystemException('Delegation file not found', path);
    }

    final bytes = await file.readAsBytes();
    
    // Try to parse as text first (identity CID)
    try {
      final content = utf8.decode(bytes).trim();
      
      // Check if it's an identity CID (starts with multibase prefix)
      // Storacha CLI with --base64 outputs: m<base64>
      if (content.startsWith('m') || content.startsWith('b') || content.startsWith('u')) {
        try {
          return Delegation.fromIdentityCid(content);
        } catch (_) {
          // Not a valid identity CID, try binary CAR
        }
      }
    } catch (_) {
      // Not UTF-8 text, must be binary
    }

    // Try as raw binary CAR file (Storacha CLI without --base64)
    // This is the simplest and recommended format
    return Delegation.fromCarBytes(bytes);
  }

  /// Parse delegation from CAR (Content Addressable aRchive) bytes
  /// 
  /// CAR files contain IPLD blocks. For delegations, the root block contains
  /// either:
  /// - A DAG-CBOR variant pointing to a UCAN block
  /// - Directly a JWT UCAN
  /// 
  /// Reference: @ucanto/core/src/delegation.js:extract()
  /// 
  /// Throws [FormatException] if the CAR data is invalid or contains no UCANs.
  factory Delegation.fromCarBytes(Uint8List bytes) {
    try {
      // Decode CAR file using the standard decoder
      final result = readCar(bytes);
      
      if (result.blocks.isEmpty) {
        throw FormatException('CAR file contains no blocks');
      }
      
      if (result.header.roots.isEmpty) {
        throw FormatException('CAR file contains no root CIDs');
      }
      
      // Find the root block
      final rootCid = result.header.roots.first;
      CARBlock? rootBlock;
      
      for (final block in result.blocks) {
        if (block.cid == rootCid) {
          rootBlock = block;
          break;
        }
      }
      
      if (rootBlock == null) {
        throw FormatException(
          'Root CID $rootCid not found in CAR blocks',
        );
      }
      
      // Try to extract UCAN from the root block
      // The block might be:
      // 1. A DAG-CBOR variant: {'ucan@0.9.1': <link-to-ucan-block>}
      // 2. A DAG-CBOR UCAN directly
      
      // Try DAG-CBOR variant format (Storacha CLI format)
      try {
        final variant = decodeSimpleDagCbor(rootBlock.bytes);
        
        if (variant is Map && variant.containsKey('ucan@0.9.1')) {
          // This is a variant pointing to a UCAN block
          final ucanCid = variant['ucan@0.9.1'];
          if (ucanCid is! CID) {
            throw FormatException('Invalid variant: ucan@0.9.1 is not a CID');
          }
          
          // Find the UCAN block
          CARBlock? ucanBlock;
          for (final block in result.blocks) {
            if (block.cid == ucanCid) {
              ucanBlock = block;
              break;
            }
          }
          
          if (ucanBlock == null) {
            throw FormatException('UCAN block with CID $ucanCid not found');
          }
          
          // Parse the UCAN as DAG-CBOR
          final ucan = decodeUcanDagCbor(ucanBlock.bytes);
          
          return Delegation(
            ucan: ucan,
            archive: bytes,
            ucanCid: ucanCid, // Store the UCAN CID for proof references
          );
        } else {
          // Root block itself might be a DAG-CBOR UCAN
          throw FormatException('Root block is not a valid variant');
        }
      } catch (e) {
        // Try decoding root block directly as DAG-CBOR UCAN
        try {
          final ucan = decodeUcanDagCbor(rootBlock.bytes);
          return Delegation(
            ucan: ucan,
            archive: bytes,
            ucanCid: rootCid, // Root is the UCAN itself
          );
        } catch (e2) {
          throw FormatException(
            'Failed to parse CAR delegation: root block is neither a valid DAG-CBOR variant nor a direct DAG-CBOR UCAN. '
            'Variant error: $e, Direct UCAN error: $e2',
          );
        }
      }
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Failed to decode CAR delegation: $e');
    }
  }

  /// Export delegation as JWT token string
  String toToken() => ucan.encode();

  /// Save delegation to a file as JWT token
  Future<void> saveToFile(String path) async {
    final file = File(path);
    await file.writeAsString(toToken());
  }

  /// Get the issuer DID (who granted the delegation)
  String get issuer => ucan.payload.issuer;

  /// Get the audience DID (who can use the delegation)
  String get audience => ucan.payload.audience;

  /// Get the capabilities granted by this delegation
  List<Capability> get capabilities => ucan.payload.capabilities;

  /// Get the proof CIDs (references to parent UCANs)
  List<CID> get proofs => ucan.payload.proofs;

  /// Check if this delegation is expired
  bool get isExpired => ucan.isExpired;

  /// Check if this delegation is valid (not expired, not too early)
  bool get isValid => ucan.isValid;

  /// Get expiration timestamp (Unix seconds, UTC)
  int? get expiration => ucan.payload.expiration;

  /// Verify that this delegation grants a specific capability
  bool grantsCapability(String ability, {String? resource}) {
    for (final cap in capabilities) {
      if (cap.can == ability) {
        if (resource == null || cap.with_ == resource) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  String toString() => 
      'Delegation(iss: $issuer, aud: $audience, caps: ${capabilities.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Delegation &&
          ucan == other.ucan &&
          _bytesEqual(archive, other.archive);

  @override
  int get hashCode => Object.hash(ucan, archive?.length ?? 0);

  bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Decode simple DAG-CBOR (exported for use in delegation parsing)
dynamic decodeSimpleDagCbor(Uint8List bytes) {
  final reader = _SimpleCborReader(bytes);
  return reader.readValue();
}

/// Simple CBOR reader for DAG-CBOR structures
class _SimpleCborReader {
  _SimpleCborReader(this.bytes) : _offset = 0;
  
  final Uint8List bytes;
  int _offset;
  
  dynamic readValue() {
    if (_offset >= bytes.length) {
      throw RangeError('Unexpected end of CBOR data');
    }
    
    final initialByte = bytes[_offset++];
    final majorType = initialByte >> 5;
    final additional = initialByte & 0x1F;
    
    switch (majorType) {
      case 0: // Unsigned integer
        return _readInt(additional);
      case 1: // Negative integer
        final value = _readInt(additional);
        return -1 - value;
      case 2: // Byte string
        final len = _readInt(additional);
        final data = bytes.sublist(_offset, _offset + len);
        _offset += len;
        return data;
      case 3: // Text string
        final len = _readInt(additional);
        final data = bytes.sublist(_offset, _offset + len);
        _offset += len;
        return utf8.decode(data);
      case 4: // Array
        final len = _readInt(additional);
        final list = <dynamic>[];
        for (int i = 0; i < len; i++) {
          list.add(readValue());
        }
        return list;
      case 5: // Map
        final len = _readInt(additional);
        final map = <String, dynamic>{};
        for (int i = 0; i < len; i++) {
          final key = readValue();
          final value = readValue();
          if (key is String) {
            map[key] = value;
          } else {
            // Skip non-string keys
            continue;
          }
        }
        return map;
      case 6: // Tag
        final tagNum = _readInt(additional);
        if (tagNum == 42) {
          // CID tag
          final nextByte = bytes[_offset++];
          final nextMajor = nextByte >> 5;
          final nextAdditional = nextByte & 0x1F;
          
          if (nextMajor != 2) {
            throw FormatException('CID tag must be followed by byte string');
          }
          
          final len = _readInt(nextAdditional);
          var cidBytes = bytes.sublist(_offset, _offset + len);
          _offset += len;
          
          // DAG-CBOR CIDs have a 0x00 prefix byte for CIDv1
          if (cidBytes.isNotEmpty && cidBytes[0] == 0x00) {
            cidBytes = cidBytes.sublist(1);
          }
          
          return CID.decode(cidBytes);
        }
        // For other tags, just read the value
        return readValue();
      case 7: // Special
        if (additional == 20) return false;
        if (additional == 21) return true;
        if (additional == 22) return null;
        throw FormatException('Unsupported special value: $additional');
      default:
        throw FormatException('Unsupported CBOR major type: $majorType');
    }
  }
  
  int _readInt(int additional) {
    if (additional < 24) {
      return additional;
    } else if (additional == 24) {
      return bytes[_offset++];
    } else if (additional == 25) {
      final val = (bytes[_offset] << 8) | bytes[_offset + 1];
      _offset += 2;
      return val;
    } else if (additional == 26) {
      final val = (bytes[_offset] << 24) | 
                  (bytes[_offset + 1] << 16) |
                  (bytes[_offset + 2] << 8) |
                  bytes[_offset + 3];
      _offset += 4;
      return val;
    } else if (additional == 27) {
      // 64-bit int - just take lower 32 bits for now
      _offset += 4; // Skip high 32 bits
      final val = (bytes[_offset] << 24) | 
                  (bytes[_offset + 1] << 16) |
                  (bytes[_offset + 2] << 8) |
                  bytes[_offset + 3];
      _offset += 4;
      return val;
    }
    throw FormatException('Unsupported int encoding');
  }
}

/// Manages a collection of delegations
class DelegationStore {
  DelegationStore([List<Delegation>? delegations])
      : _delegations = List.from(delegations ?? []);

  final List<Delegation> _delegations;

  /// Add a delegation to the store
  void add(Delegation delegation) {
    _delegations.add(delegation);
  }

  /// Add multiple delegations
  void addAll(List<Delegation> delegations) {
    _delegations.addAll(delegations);
  }

  /// Remove a delegation from the store
  bool remove(Delegation delegation) {
    return _delegations.remove(delegation);
  }

  /// Get all delegations
  List<Delegation> get all => List.unmodifiable(_delegations);

  /// Get delegations that grant a specific capability
  List<Delegation> findByCapability(String ability, {String? resource}) {
    return _delegations
        .where((d) => d.grantsCapability(ability, resource: resource))
        .toList();
  }

  /// Get delegations for a specific audience (agent DID)
  List<Delegation> findByAudience(String audienceDid) {
    return _delegations.where((d) => d.audience == audienceDid).toList();
  }

  /// Get all valid (non-expired) delegations
  List<Delegation> get valid {
    return _delegations.where((d) => d.isValid).toList();
  }

  /// Get proof tokens for invocations
  /// 
  /// Returns a list of JWT strings that should be included
  /// as proofs when invoking capabilities.
  List<String> getProofTokens({
    String? forCapability,
    String? forResource,
    String? forAudience,
  }) {
    var delegations = valid;

    if (forCapability != null) {
      delegations = delegations
          .where((d) => d.grantsCapability(forCapability, resource: forResource))
          .toList();
    }

    if (forAudience != null) {
      delegations = delegations.where((d) => d.audience == forAudience).toList();
    }

    return delegations.map((d) => d.toToken()).toList();
  }

  /// Clear all delegations
  void clear() {
    _delegations.clear();
  }

  /// Number of delegations in the store
  int get length => _delegations.length;

  /// Check if store is empty
  bool get isEmpty => _delegations.isEmpty;

  /// Check if store is not empty
  bool get isNotEmpty => _delegations.isNotEmpty;
}

