/// Encode UCAN invocations to CAR format for HTTP transport
library;

import 'dart:typed_data';

import 'package:storacha_dart/src/core/encoding.dart';
import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';

/// Encode a UCAN invocation JWT to CAR format
///
/// The CAR file contains a single block with the JWT encoded as CBOR.
/// The root CID is the SHA-256 hash of the JWT.
///
/// This format is used for HTTP POST requests to Storacha services.
Uint8List encodeInvocationToCar(String jwt) {
  // Step 1: Encode as CBOR (JWT is already a string, wrap in CBOR string)
  final cborBytes = encodeCbor(jwt);

  // Step 3: Create CID from SHA-256 hash
  // Use raw codec (0x55) for the invocation
  final digest = sha256Hash(cborBytes);
  final cid = CID.createV1(rawCode, digest);

  // Step 4: Create CAR block
  final block = CARBlock(cid: cid, bytes: cborBytes);

  // Step 5: Encode to CAR with root CID
  return encodeCar(roots: [cid], blocks: [block]);
}

/// Encode invocation with additional context blocks
///
/// Used when the invocation references other CIDs (e.g., proofs, linked data).
Uint8List encodeInvocationWithBlocks({
  required String jwt,
  List<CARBlock> additionalBlocks = const [],
}) {
  // Encode main invocation
  final jwtBytes = encodeCbor(jwt);
  final digest = sha256Hash(jwtBytes);
  final rootCid = CID.createV1(rawCode, digest);

  final rootBlock = CARBlock(cid: rootCid, bytes: jwtBytes);

  // Combine all blocks
  final allBlocks = [rootBlock, ...additionalBlocks];

  // Encode to CAR
  return encodeCar(roots: [rootCid], blocks: allBlocks);
}

