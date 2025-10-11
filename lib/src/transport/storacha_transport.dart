/// HTTP transport for Storacha network communication
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';

/// Transport for communicating with Storacha services
class StorachaTransport {
  StorachaTransport({
    String? endpoint,
    Dio? dio,
  })  : endpoint = endpoint ?? 'https://up.storacha.network',
        _dio = dio ?? Dio();

  /// Storacha service endpoint
  final String endpoint;

  /// HTTP client
  final Dio _dio;

  /// Invoke space/blob/add capability
  ///
  /// Returns allocation information for uploading the blob.
  Future<BlobAllocation> invokeBlobAdd({
    required String spaceDid,
    required BlobDescriptor blob,
    required UcanInvocation invocation,
  }) async {
    // TODO(network): Implement UCAN invocation transport
    // Steps:
    // 1. Encode invocation to CAR
    // 2. POST to endpoint
    // 3. Parse response
    // 4. Return BlobAllocation

    throw UnimplementedError(
      'space/blob/add invocation not yet implemented. '
      'Requires CAR encoding for UCAN and HTTP POST.',
    );
  }

  /// Upload blob to allocated URL
  ///
  /// Performs HTTP PUT of the blob data to the provided URL.
  Future<void> uploadBlob({
    required String url,
    required Uint8List data,
    required Map<String, String> headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    // TODO(network): Implement blob upload
    // Use Dio to PUT data to URL with headers

    throw UnimplementedError(
      'Blob upload not yet implemented. '
      'Requires HTTP PUT with progress tracking.',
    );
  }

  /// Invoke upload/add capability
  ///
  /// Registers the uploaded DAG with the service.
  Future<UploadResult> invokeUploadAdd({
    required String spaceDid,
    required CID root,
    required List<CID> shards,
    required UcanInvocation invocation,
  }) async {
    // TODO(network): Implement UCAN invocation transport
    // Similar to invokeBlobAdd but for upload/add

    throw UnimplementedError(
      'upload/add invocation not yet implemented. '
      'Requires CAR encoding for UCAN and HTTP POST.',
    );
  }

  /// Close the HTTP client
  void close() {
    _dio.close();
  }
}

