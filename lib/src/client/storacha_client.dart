/// Main Storacha client for interacting with the Storacha Network
library;

import 'package:dio/dio.dart';
import 'package:storacha_dart/src/client/client_config.dart';
import 'package:storacha_dart/src/client/space.dart';
import 'package:storacha_dart/src/crypto/signer.dart';
import 'package:storacha_dart/src/ipfs/car/car_encoder.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/unixfs/unixfs_encoder.dart';
import 'package:storacha_dart/src/ipfs/unixfs/unixfs_types.dart';
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
  StorachaClient(ClientConfig config)
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
        );

  final ClientConfig _config;
  final Dio _http;

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

    // TODO(upload): Network upload implementation required
    // Remaining tasks:
    // - HTTP client integration with Dio
    // - UCAN authorization headers
    // - space/blob/add capability invocation
    // - upload/add capability registration
    // - Proper error handling and retries
    // - Background upload support for mobile
    //
    // Currently returns root CID after local encoding only

    // Track upload progress if callback provided
    if (options?.onUploadProgress != null) {
      options!.onUploadProgress!(
        ProgressStatus(
          loaded: carBytes.length,
          total: carBytes.length,
        ),
      );
    }

    return unixfsResult.rootCID;
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
  }
}
