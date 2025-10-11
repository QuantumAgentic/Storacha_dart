/// HTTP transport for Storacha network communication
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:storacha_dart/src/core/network_retry.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';
import 'package:storacha_dart/src/ucan/invocation_encoder.dart';

/// Exception thrown when Storacha service returns an error
class StorachaException implements Exception {
  StorachaException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  @override
  String toString() {
    final buffer = StringBuffer('StorachaException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write('\nDetails: $details');
    return buffer.toString();
  }
}

/// Transport for communicating with Storacha services
class StorachaTransport {
  StorachaTransport({
    String? endpoint,
    Dio? dio,
    RetryConfig? retryConfig,
  })  : endpoint = endpoint ?? 'https://up.storacha.network',
        _dio = dio ?? Dio(),
        retryConfig = retryConfig ?? RetryPresets.standard;

  /// Storacha service endpoint
  final String endpoint;

  /// HTTP client
  final Dio _dio;

  /// Retry configuration for network requests
  final RetryConfig retryConfig;

  /// Invoke a UCAN capability on the Storacha service
  ///
  /// Encodes the invocation as a CAR file and POSTs it to the endpoint.
  /// Returns the response body as a Map.
  Future<Map<String, dynamic>> invokeCapability({
    required InvocationBuilder builder,
    int? expiration,
    String? nonce,
  }) async {
    // Step 1: Sign the invocation to get JWT
    final jwt = await builder.sign(expiration: expiration, nonce: nonce);

    // Step 2: Encode JWT to CAR format
    final carBytes = encodeInvocationToCar(jwt);

    // Step 3: POST to Storacha with retry
    final retry = ExponentialBackoffRetry(config: retryConfig);

    final response = await retry.execute<Response<dynamic>>(
      () async {
        return _dio.post<dynamic>(
          endpoint,
          data: carBytes,
          options: Options(
            contentType: 'application/vnd.ipld.car',
            responseType: ResponseType.json,
            headers: {
              'Accept': 'application/json',
            },
          ),
        );
      },
    );

    // Step 4: Parse response
    return _parseResponse(response);
  }

  /// Invoke space/blob/add capability
  ///
  /// Returns allocation information for uploading the blob.
  Future<BlobAllocation> invokeBlobAdd({
    required String spaceDid,
    required BlobDescriptor blob,
    required InvocationBuilder builder,
  }) async {
    final response = await invokeCapability(builder: builder);

    // Parse the response
    if (response.containsKey('error')) {
      throw _parseError(response);
    }

    final ok = response['ok'] as Map<String, dynamic>?;
    if (ok == null) {
      throw StorachaException(
        'Invalid response: missing "ok" field',
        details: response,
      );
    }

    return BlobAllocation.fromJson(ok);
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
    final retry = ExponentialBackoffRetry(config: retryConfig);

    await retry.execute<Response<dynamic>>(
      () async {
        return _dio.put<dynamic>(
          url,
          data: Stream.fromIterable([data]),
          options: Options(
            contentType: 'application/vnd.ipld.car',
            headers: headers,
          ),
          onSendProgress: onProgress,
        );
      },
    );
  }

  /// Invoke upload/add capability
  ///
  /// Registers the uploaded DAG with the service.
  Future<UploadResult> invokeUploadAdd({
    required String spaceDid,
    required CID root,
    required List<CID> shards,
    required InvocationBuilder builder,
  }) async {
    final response = await invokeCapability(builder: builder);

    // Parse the response
    if (response.containsKey('error')) {
      throw _parseError(response);
    }

    final ok = response['ok'] as Map<String, dynamic>?;
    if (ok == null) {
      throw StorachaException(
        'Invalid response: missing "ok" field',
        details: response,
      );
    }

    return UploadResult.fromJson(ok);
  }

  /// Parse HTTP response
  Map<String, dynamic> _parseResponse(Response<dynamic> response) {
    if (response.statusCode != 200) {
      throw StorachaException(
        'HTTP ${response.statusCode}: ${response.statusMessage}',
        code: response.statusCode.toString(),
      );
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is String) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        throw StorachaException(
          'Failed to parse JSON response: $e',
          details: {'raw': data},
        );
      }
    } else {
      throw StorachaException(
        'Unexpected response type: ${data.runtimeType}',
        details: {'data': data},
      );
    }
  }

  /// Parse error from response
  StorachaException _parseError(Map<String, dynamic> response) {
    final error = response['error'] as Map<String, dynamic>?;
    if (error == null) {
      return StorachaException(
        'Unknown error',
        details: response,
      );
    }

    return StorachaException(
      error['message']?.toString() ?? 'Unknown error',
      code: error['name']?.toString(),
      details: error,
    );
  }

  /// Close the HTTP client
  void close() {
    _dio.close();
  }
}
