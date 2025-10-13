/// HTTP transport for Storacha network communication
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:storacha_dart/src/core/network_retry.dart';
import 'package:storacha_dart/src/ipfs/car/car_reader.dart';
import 'package:storacha_dart/src/ipfs/car/car_types.dart';
import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ucan/capability_types.dart';
import 'package:storacha_dart/src/ucan/delegation.dart';
import 'package:storacha_dart/src/ucan/invocation.dart';

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
    String? receiptEndpoint,
    Dio? dio,
    RetryConfig? retryConfig,
  })  : endpoint = endpoint ?? 'https://up.storacha.network',
        receiptEndpoint = receiptEndpoint ?? 'https://up.storacha.network/receipt',
        _dio = dio ?? Dio(),
        retryConfig = retryConfig ?? RetryPresets.standard;

  /// Storacha service endpoint
  final String endpoint;

  /// Receipt polling endpoint
  final String receiptEndpoint;

  /// HTTP client
  final Dio _dio;

  /// Retry configuration for network requests
  final RetryConfig retryConfig;

  /// Invoke a UCAN capability on the Storacha service
  ///
  /// Encodes the invocation as a CAR file (IPLD format) and POSTs it to the endpoint.
  /// Returns the response body as a Map.
  Future<Map<String, dynamic>> invokeCapability({
    required InvocationBuilder builder,
    int? expiration,
    String? nonce,
  }) async {
    // Step 1: Extract proof CIDs from archives and add to builder
    for (final archive in builder.proofArchives) {
      try {
        // Parse the delegation to get the actual UCAN CID
        final delegation = Delegation.fromCarBytes(archive);
        if (delegation.ucanCid != null) {
          builder.addProof(delegation.ucanCid.toString());
        }
      } catch (e) {
        throw StorachaException(
          'Failed to parse delegation archive: $e',
          code: 'DELEGATION_PARSE_ERROR',
        );
      }
    }

    // Step 2: Build the UCANTO message (ucanto/message@7.0.0 format)
    final message = await builder.buildMessage(
      expiration: expiration,
      nonce: nonce,
    );

    // Step 3: Encode to CAR format
    final carBytes = message.toCAR();

    // Step 4: POST to Storacha with retry
    final retry = ExponentialBackoffRetry(config: retryConfig);

    final response = await retry.execute<Response<dynamic>>(
      () async {
        try {
          return await _dio.post<dynamic>(
            endpoint,
            data: carBytes,
            options: Options(
              contentType: 'application/vnd.ipld.car',
              responseType: ResponseType.bytes, // Response is CAR format
              headers: {
                'Accept': 'application/vnd.ipld.car', // Request CAR response
              },
              validateStatus: null, // Don't throw on non-2xx status
            ),
          );
        } catch (e) {
          if (e is DioException && e.response != null) {
            print('DEBUG: HTTP ${e.response?.statusCode} response body: ${e.response?.data}');
          }
          rethrow;
        }
      },
    );

    // Step 5: Parse response
    if (response.statusCode! >= 400) {
      print('DEBUG: Error response (${response.statusCode}): ${response.data}');
      throw StorachaException(
        'HTTP ${response.statusCode}: ${response.statusMessage}',
        code: response.statusCode.toString(),
        details: response.data is Map ? response.data as Map<String, dynamic> : null,
      );
    }

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
    
    print('DEBUG space/blob/add response: $response');

    // Parse the response - can be either 'ok' or 'report' format
    if (response.containsKey('error')) {
      throw _parseError(response);
    }

    // Try 'ok' field first (direct response)
    final ok = response['ok'] as Map<String, dynamic>?;
    if (ok != null) {
      return BlobAllocation.fromJson(ok);
    }

    // Try 'report' field (ucanto/message@7.0.0 format with receipts)
    // The response format is: {ucanto/message@7.0.0: {report: {invocationCid: receiptCid}}}
    final messageData = response['ucanto/message@7.0.0'] as Map<String, dynamic>?;
    if (messageData != null) {
      final report = messageData['report'] as Map<String, dynamic>?;
      if (report != null && report.isNotEmpty) {
        // Extract the receipt CID (value of the first entry in report)
        // The report contains CID objects or strings
        // For now, assume blob was already uploaded (allocated: false)
        return BlobAllocation(
          allocated: false,
          url: null,
          headers: null,
        );
      }
    }

    throw StorachaException(
      'Invalid response: missing "ok" or "report" field',
      details: response,
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

    // Parse the response - can be either 'ok' or 'report' format
    if (response.containsKey('error')) {
      throw _parseError(response);
    }

    // Try 'ok' field first (direct response)
    final ok = response['ok'] as Map<String, dynamic>?;
    if (ok != null) {
      return UploadResult.fromJson(ok);
    }

    // Try 'report' field (ucanto/message@7.0.0 format with receipts)
    final messageData = response['ucanto/message@7.0.0'] as Map<String, dynamic>?;
    if (messageData != null) {
      final report = messageData['report'] as Map<String, dynamic>?;
      if (report != null && report.isNotEmpty) {
        // Debug: Print report content
        print('DEBUG upload/add report: $report');
        
        // Extract receipts from CAR blocks (they're already in the response!)
        for (final entry in report.entries) {
          final receiptCidString = entry.value.toString();
          print('DEBUG: Extracting receipt from CAR blocks: $receiptCidString');
          
          try {
            final receiptCid = CID.parse(receiptCidString);
            
            // Find the receipt block in the CAR response
            CARBlock? receiptBlock;
            for (final block in _lastCarBlocks) {
              if (block.cid.toString() == receiptCid.toString()) {
                receiptBlock = block;
                break;
              }
            }
            
            if (receiptBlock == null) {
              print('WARNING: Receipt block not found in CAR response, trying poll...');
              // Fallback to polling if not in blocks
              final receiptData = await pollReceipt(receiptCid, timeout: Duration(seconds: 10));
              if (receiptData == null) {
                throw StorachaException('Receipt not found in CAR and polling failed');
              }
              
              // Check receipt
              final out = receiptData['out'] as Map<String, dynamic>?;
              if (out != null && out.containsKey('error')) {
                throw StorachaException(
                  'Upload registration failed: ${out['error']}',
                  details: out,
                );
              }
              
              print('DEBUG: Receipt OK (polled): $out');
              return UploadResult(root: root, shards: shards);
            }
            
            // Decode receipt block
            final receiptData = decodeSimpleDagCbor(receiptBlock.bytes);
            print('DEBUG: Receipt data: $receiptData');
            
            // Receipt structure: {ocm: {out: ..., iss: ..., ran: ..., prf: ...}, sig: ...}
            // Extract the outcome (ocm)
            final ocm = receiptData['ocm'] as Map<String, dynamic>?;
            if (ocm == null) {
              throw StorachaException(
                'Invalid receipt format: missing ocm field',
                details: receiptData is Map ? Map<String, dynamic>.from(receiptData) : null,
              );
            }
            
            // Check for 'out' field which contains the result
            final out = ocm['out'] as Map<String, dynamic>?;
            if (out == null) {
              throw StorachaException(
                'Invalid receipt format: missing out field',
                details: receiptData is Map ? Map<String, dynamic>.from(receiptData) : null,
              );
            }
            
            // Check if out contains an error
            if (out.containsKey('error')) {
              final error = out['error'] as Map<String, dynamic>?;
              throw StorachaException(
                'Upload registration failed: ${error?['message'] ?? error?['name'] ?? 'Unknown error'}',
                details: error,
              );
            }
            
            // Check if out contains ok
            if (out.containsKey('ok')) {
              print('DEBUG: Receipt OK: ${out['ok']}');
              return UploadResult(root: root, shards: shards);
            }
            
            // Unknown out format
            throw StorachaException(
              'Invalid receipt format: out field has neither ok nor error',
              details: out,
            );
            
          } catch (e) {
            print('ERROR extracting receipt: $e');
            rethrow;
          }
        }
        
        // If we get here, no receipt was successfully processed
        return UploadResult(root: root, shards: shards);
      }
    }

    throw StorachaException(
      'Invalid response: missing "ok" or "report" field',
      details: response,
    );
  }

  /// Last received CAR blocks (for extracting receipts)
  List<CARBlock> _lastCarBlocks = [];

  /// Parse HTTP response (CAR format)
  Map<String, dynamic> _parseResponse(Response<dynamic> response) {
    final data = response.data;
    
    // Response is CAR bytes, decode it
    if (data is Uint8List || data is List<int>) {
      try {
        final carBytes = data is Uint8List ? data : Uint8List.fromList(data as List<int>);
        final carResult = readCar(carBytes);
        
        // Store all blocks for later receipt extraction
        _lastCarBlocks = carResult.blocks;
        
        // The root block contains the response
        if (carResult.header.roots.isEmpty) {
          throw FormatException('CAR response has no root CID');
        }
        
        final rootCid = carResult.header.roots.first;
        CARBlock? rootBlock;
        for (final block in carResult.blocks) {
          if (block.cid == rootCid) {
            rootBlock = block;
            break;
          }
        }
        
        if (rootBlock == null) {
          throw FormatException('Root block not found in CAR');
        }
        
        // Decode root block as CBOR to get response JSON
        final cborData = decodeSimpleDagCbor(rootBlock.bytes);
        if (cborData is Map) {
          return Map<String, dynamic>.from(cborData);
        } else {
          throw FormatException('Root block is not a map');
        }
      } catch (e) {
        throw StorachaException(
          'Failed to parse CAR response: $e',
          details: {'raw': data.runtimeType.toString()},
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

  /// Poll and retrieve a receipt
  ///
  /// Retrieves the receipt CAR and extracts the result.
  /// Returns null if receipt is not ready yet (should retry).
  Future<Map<String, dynamic>?> pollReceipt(CID receiptCid, {
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _dio.get<dynamic>(
          '$receiptEndpoint/${receiptCid.toString()}',
          options: Options(
            responseType: ResponseType.bytes,
            validateStatus: (status) => status! < 500, // Allow 4xx errors
          ),
        );
        
        if (response.statusCode == 404) {
          // Receipt not ready yet, wait and retry
          print('DEBUG: Receipt not ready, retrying in ${pollInterval.inSeconds}s...');
          await Future<void>.delayed(pollInterval);
          continue;
        }
        
        if (response.statusCode! >= 400) {
          throw StorachaException(
            'Failed to fetch receipt: HTTP ${response.statusCode}',
            code: response.statusCode.toString(),
          );
        }
        
        // Parse CAR response
        final carBytes = response.data as Uint8List;
        final carResult = readCar(carBytes);
        
        // Find the receipt block (root of CAR)
        if (carResult.header.roots.isEmpty) {
          throw StorachaException('Receipt CAR has no roots');
        }
        
        final receiptRoot = carResult.header.roots.first;
        final receiptBlock = carResult.blocks.firstWhere(
          (b) => b.cid.toString() == receiptRoot.toString(),
          orElse: () => throw StorachaException('Receipt root block not found'),
        );
        
        // Decode receipt (should be CBOR)
        final receiptData = decodeSimpleDagCbor(receiptBlock.bytes);
        print('DEBUG: Receipt data: $receiptData');
        
        // Cast to the expected return type
        return receiptData is Map ? Map<String, dynamic>.from(receiptData) : null;
        
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 404) {
          // Receipt not ready, retry
          await Future<void>.delayed(pollInterval);
          continue;
        }
        rethrow;
      }
    }
    
    // Timeout
    throw StorachaException(
      'Receipt polling timeout after ${timeout.inSeconds}s',
      code: 'RECEIPT_TIMEOUT',
    );
  }

  /// Close the HTTP client
  void close() {
    _dio.close();
  }
}
