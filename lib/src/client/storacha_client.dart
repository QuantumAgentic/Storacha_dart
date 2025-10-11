/// Main Storacha client for interacting with the Storacha Network
library;

import 'package:dio/dio.dart';
import 'package:storacha_dart/src/client/client_config.dart';
import 'package:storacha_dart/src/client/space.dart';
import 'package:storacha_dart/src/crypto/signer.dart';

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
    if (_currentSpace == null) {
      _currentSpace = space;
    }

    return space;
  }

  /// Add an existing space to this client
  ///
  /// Use this to add a space that was created elsewhere or restored from backup.
  void addSpace(Space space) {
    // Check if space already exists
    final exists = _spaces.any((s) => s.did == space.did);
    if (exists) {
      throw ArgumentError('Space with DID ${space.did} already exists');
    }

    _spaces.add(space);

    // Set as current space if it's the first one
    if (_currentSpace == null) {
      _currentSpace = space;
    }
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

  /// Close the client and release resources
  void close() {
    _http.close();
  }
}

