/// Main Storacha client for interacting with the Storacha Network
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:storacha_dart/src/client/client_config.dart';
import 'package:storacha_dart/src/client/space.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:storacha_dart/src/ipfs/unixfs/unixfs_encoder.dart';
import 'package:storacha_dart/src/ipfs/unixfs/unixfs_types.dart';
import 'package:storacha_dart/src/transport/storacha_transport.dart';
import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';
import 'package:storacha_dart/src/upload/blob.dart';
import 'package:storacha_dart/src/upload/upload_options.dart';

/// Main client for Storacha Network
///
/// Provides access to:
/// - Space management (create, list, select)
/// - File uploads
/// - UCAN delegation
/// - Storage proofs and receipts
class StorachaClient {
  StorachaClient(ClientConfig config, {StorachaTransport? transport})
      : _config = config,
        _http = Dio(
          BaseOptions(
            baseUrl: config.endpoints.serviceUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'storacha-dart/0.1.0',
            },
          ),
        ),
        _transport = transport ?? StorachaTransport();

  final ClientConfig _config;
  final Dio _http;
  final StorachaTransport _transport;

  /// Currently selected space
  Space? _currentSpace;

  /// List of all spaces available to this client
  final List<Space> _spaces = [];

  /// Get client's principal (agent) DID
  String did() => _config.principal.did().did();

  /// Get the default service provider DID
  String defaultProvider() => _config.defaultProvider;

  /// Get the current space
  Space? currentSpace() => _currentSpace;

  /// List all spaces
  List<Space> spaces() => List.unmodifiable(_spaces);

  /// Set the current space
  ///
  /// Throws [ArgumentError] if space with given DID is not found
  void setCurrentSpace(String spaceDid) {
    final space = _spaces.firstWhere(
      (s) => s.did == spaceDid,
      orElse: () => throw ArgumentError(
        'Space with DID $spaceDid not found. '
        'Available spaces: ${_spaces.map((s) => s.did).join(", ")}',
      ),
    );
    _currentSpace = space;
  }

  /// Create a new space
  ///
  /// A space is a storage namespace with its own DID and capabilities.
  /// 
  /// Example:
  /// ```dart
  /// final space = await client.createSpace('My Photos');
  /// ```
  Future<Space> createSpace(
    String name, {
    Signer? spaceSigner,
  }) async {
    // Generate a new signer for the space if not provided
    final signer = spaceSigner ?? await Ed25519Signer.generate();

    // Create space object
    final space = Space(
      did: signer.did().did(),
      name: name,
      signer: signer,
      createdAt: DateTime.now(),
    );

    // Add to spaces list
    _spaces.add(space);

    // Set as current space if it's the first one
    _currentSpace ??= space;

    return space;
  }

  /// Add an existing space to this client
  ///
  /// Use this to add a space that was created elsewhere
  /// or restored from backup.
  void addSpace(Space space) {
    // Check if space already exists
    final exists = _spaces.any((s) => s.did == space.did);
    if (exists) {
      throw ArgumentError('Space with DID ${space.did} already exists');
    }

    _spaces.add(space);

    // Set as current space if it's the first one
    _currentSpace ??= space;
  }

  /// Remove a space from this client
  ///
  /// Returns `true` if the space was removed, `false` if not found
  bool removeSpace(String spaceDid) {
    final index = _spaces.indexWhere((s) => s.did == spaceDid);
    if (index == -1) {
      return false;
    }

    final removedSpace = _spaces.removeAt(index);

    // If we removed the current space, select another one
    if (_currentSpace?.did == removedSpace.did) {
      _currentSpace = _spaces.isNotEmpty ? _spaces.first : null;
    }

    return true;
  }

  /// Upload a file to the current space
  ///
  /// Uploads a file to Storacha and returns the root CID of the generated DAG.
  ///
  /// This performs the complete upload flow:
  /// 1. Encode file to UnixFS DAG
  /// 2. Package into CAR format
  /// 3. Request blob allocation from Storacha
  /// 4. Upload CAR file to allocated URL
  /// 5. Register upload with Storacha service
  ///
  /// Required:
  /// - A current space must be selected
  ///
  /// Example:
  /// ```dart
  /// final file = MemoryFile(
  ///   name: 'photo.jpg',
  ///   bytes: imageBytes,
  /// );
  ///
  /// final cid = await client.uploadFile(
  ///   file,
  ///   options: UploadFileOptions(
  ///     onUploadProgress: (status) {
  ///       print('Uploaded ${status.percentage}%');
  ///     },
  ///   ),
  /// );
  ///
  /// print('File uploaded! CID: $cid');
  /// ```
  ///
  /// Throws [StateError] if no space is currently selected.
  /// Throws [StorachaException] if the upload fails.
  Future<CID> uploadFile(
    BlobLike file, {
    UploadFileOptions? options,
  }) async {
    if (_currentSpace == null) {
      throw StateError(
        'No space selected. Call setCurrentSpace() or createSpace() first.',
      );
    }

    // Step 1: Encode file to UnixFS DAG
    final unixfsEncoder = UnixFSEncoder(
      options: UnixFSEncodeOptions(
        chunkSize: options?.chunkSize ?? 256 * 1024,
      ),
    );

    final unixfsResult = await unixfsEncoder.encodeFile(file);

    // Step 2: Convert IPLD blocks to CAR blocks
    final carBlocks = unixfsResult.blocks
        .map(
          (block) => CARBlock(
            cid: block.cid,
            bytes: block.bytes,
          ),
        )
        .toList();

    // Step 3: Generate CAR file
    final carBytes = encodeCar(
      roots: [unixfsResult.rootCID],
      blocks: carBlocks,
    );

    // Step 4: Calculate CAR digest for blob descriptor
    final carMultihash = sha256Hash(carBytes);
    final carDigest = carMultihash.digest;

    // Step 5: Request blob allocation (space/blob/add capability)
    final blobDescriptor = BlobDescriptor(
      digest: carDigest,
      size: carBytes.length,
    );

    final blobCapability = Capability(
      with_: _currentSpace!.did,
      can: 'space/blob/add',
      nb: {
        'blob': {
          'digest': carDigest,
          'size': carBytes.length,
        },
      },
    );

    final blobBuilder = InvocationBuilder(signer: _config.principal)
      ..addCapability(blobCapability);

    final allocation = await _transport.invokeBlobAdd(
      spaceDid: _currentSpace!.did,
      blob: blobDescriptor,
      builder: blobBuilder,
    );

    // Step 6: Upload CAR file to allocated URL (if newly allocated)
    if (allocation.allocated && allocation.url != null) {
      await _transport.uploadBlob(
        url: allocation.url!,
        data: Uint8List.fromList(carBytes),
        headers: allocation.headers ?? {},
        onProgress: options?.onUploadProgress != null
            ? (sent, total) {
                options!.onUploadProgress!(
                  ProgressStatus(loaded: sent, total: total),
                );
              }
            : null,
      );
    } else {
      // Blob already exists, just notify 100% progress
      if (options?.onUploadProgress != null) {
        options!.onUploadProgress!(
          ProgressStatus(loaded: carBytes.length, total: carBytes.length),
        );
      }
    }

    // Step 7: Register upload (upload/add capability)
    final carCid = CID.createV1(rawCode, carMultihash);

    final uploadCapability = Capability(
      with_: _currentSpace!.did,
      can: 'upload/add',
      nb: {
        'root': unixfsResult.rootCID.toString(),
        'shards': [carCid.toString()],
      },
    );

    final uploadBuilder = InvocationBuilder(signer: _config.principal)
      ..addCapability(uploadCapability);

    final uploadResult = await _transport.invokeUploadAdd(
      spaceDid: _currentSpace!.did,
      root: unixfsResult.rootCID,
      shards: [carCid],
      builder: uploadBuilder,
    );

    return uploadResult.root;
  }

  /// Upload a directory of files to the current space
  ///
  /// Uploads multiple files as a directory structure and returns the root CID
  /// of the generated DAG. File paths are preserved in the directory structure.
  ///
  /// Required:
  /// - A current space must be selected
  ///
  /// Example:
  /// ```dart
  /// final files = [
  ///   MemoryFile(name: 'README.md', bytes: readme),
  ///   MemoryFile(name: 'src/main.dart', bytes: mainDart),
  ///   MemoryFile(name: 'assets/logo.png', bytes: logo),
  /// ];
  ///
  /// final cid = await client.uploadDirectory(
  ///   files,
  ///   options: UploadDirectoryOptions(
  ///     customOrder: true,
  ///     onUploadProgress: (status) {
  ///       print('Progress: ${status.percentage}%');
  ///     },
  ///   ),
  /// );
  ///
  /// print('Directory uploaded! Root CID: $cid');
  /// ```
  ///
  /// Throws [StateError] if no space is currently selected.
  /// Throws [ArgumentError] if the files list is empty.
  Future<CID> uploadDirectory(
    List<FileLike> files, {
    UploadDirectoryOptions? options,
  }) async {
    if (_currentSpace == null) {
      throw StateError(
        'No space selected. Call setCurrentSpace() or createSpace() first.',
      );
    }

    if (files.isEmpty) {
      throw ArgumentError('Cannot upload an empty directory');
    }

    // Implementation planned for future release
    // Required steps:
    // 1. UnixFS directory DAG encoding (encode directory structure)
    // 2. CAR file creation for all files and directory nodes
    // 3. Shard large uploads into multiple CARs
    // 4. Generate blob index
    // 5. Upload blobs via space/blob/add capability
    // 6. Register upload via upload/add capability
    // 7. Submit to Filecoin via filecoin/offer capability
    throw UnimplementedError(
      'uploadDirectory is not yet implemented. '
      'Requires UnixFS directory encoding and CAR file support. '
      'Track progress at: https://github.com/storacha/storacha-dart',
    );
  }

  /// Close the client and release resources
  void close() {
    _http.close();
    _transport.close();
  }
}
