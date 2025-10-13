/// UCAN DAG-CBOR codec
/// 
/// Based on @ipld/dag-ucan/src/codec/cbor.js
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/did_decoder.dart';
import 'package:storacha_dart/src/ucan/ucan.dart';

/// Decode UCAN from DAG-CBOR bytes
/// 
/// Reference: @ipld/dag-ucan/src/codec/cbor.js:decode()
UCAN decodeUcanDagCbor(Uint8List bytes) {
  // Decode CBOR to get the model
  final model = _decodeDagCbor(bytes);
  
  // Extract fields with safe type checking
  // Reference: @ipld/dag-ucan/src/schema.js:readPayload()
  final version = _getString(model, 'v') ?? '0.9.1';
  
  final signature = _getBytes(model, 's');
  if (signature == null) {
    throw FormatException('Missing required field: signature (s)');
  }
  
  // Decode principals from bytes (schema.js:readPrincipal -> did.js:decode)
  final issuerBytes = _getBytes(model, 'iss');
  if (issuerBytes == null) {
    throw FormatException('Missing required field: issuer (iss)');
  }
  final issuer = decodeDid(issuerBytes);
  
  final audienceBytes = _getBytes(model, 'aud');
  if (audienceBytes == null) {
    throw FormatException('Missing required field: audience (aud)');
  }
  final audience = decodeDid(audienceBytes);
  
  final attenuations = model['att'] as List? ?? [];
  final expiration = _getInt(model, 'exp');
  final notBefore = _getInt(model, 'nbf');
  final facts = (model['fct'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final proofs = _getCidList(model, 'prf');
  final nonce = _getString(model, 'nnc');
  
  // Convert attenuations to capabilities
  final capabilities = <Capability>[];
  for (final att in attenuations) {
    final attMap = att as Map<String, dynamic>;
    capabilities.add(Capability(
      with_: attMap['with'] as String,
      can: attMap['can'] as String,
      nb: attMap['nb'] as Map<String, dynamic>?,
    ));
  }
  
  // Create header
  final header = UCANHeader(
    version: version,
    algorithm: 'EdDSA',  // DAG-CBOR UCANs use EdDSA
  );
  
  // Create payload
  final payload = UCANPayload(
    issuer: issuer,
    audience: audience,
    capabilities: capabilities,
    expiration: expiration,
    notBefore: notBefore,
    nonce: nonce,
    facts: facts,
    proofs: proofs,
  );
  
  return UCAN(
    header: header,
    payload: payload,
    signature: signature,
  );
}

/// Decode DAG-CBOR to Map
Map<String, dynamic> _decodeDagCbor(Uint8List bytes) {
  final reader = _CborReader(bytes);
  final result = reader.readValue();
  
  if (result is! Map<String, dynamic>) {
    throw FormatException('Expected map at root');
  }
  
  return result;
}

/// CBOR reader for DAG-CBOR
class _CborReader {
  _CborReader(this.bytes) : _offset = 0;
  
  final Uint8List bytes;
  int _offset;
  
  dynamic readValue() {
    final byte = bytes[_offset++];
    final majorType = byte >> 5;
    final additional = byte & 0x1F;
    
    switch (majorType) {
      case 0: // Unsigned int
        return _readInt(additional);
      case 1: // Negative int
        return -1 - _readInt(additional);
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
          if (key is! String) {
            throw FormatException('Map key must be string');
          }
          map[key] = value;
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

/// Helper: safely get string from model
String? _getString(Map<String, dynamic> model, String key) {
  final value = model[key];
  if (value == null) return null;
  if (value is String) return value;
  return null;
}

/// Helper: safely get bytes from model
Uint8List? _getBytes(Map<String, dynamic> model, String key) {
  final value = model[key];
  if (value == null) return null;
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  return null;
}

/// Helper: safely get int from model
int? _getInt(Map<String, dynamic> model, String key) {
  final value = model[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return null;
}

/// Helper: safely get list of CIDs from model
List<CID> _getCidList(Map<String, dynamic> model, String key) {
  final value = model[key];
  if (value == null) return [];
  if (value is! List) return [];
  
  final result = <CID>[];
  for (final item in value) {
    if (item is CID) {
      result.add(item);
    }
  }
  return result;
}


