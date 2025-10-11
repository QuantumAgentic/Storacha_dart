/// Configuration for Storacha client
library;

import 'package:storacha_dart/src/crypto/signer.dart';

/// Storacha network endpoints
class StorachaEndpoints {
  const StorachaEndpoints({
    this.serviceUrl = 'https://up.storacha.network',
    this.receiptUrl = 'https://up.storacha.network/receipt',
  });

  /// Main service endpoint
  final String serviceUrl;

  /// Receipt polling endpoint
  final String receiptUrl;

  /// Production endpoints
  static const production = StorachaEndpoints();

  /// Development/staging endpoints
  static const staging = StorachaEndpoints(
    serviceUrl: 'https://staging.up.storacha.network',
    receiptUrl: 'https://staging.up.storacha.network/receipt',
  );
}

/// Configuration options for Storacha client
class ClientConfig {
  const ClientConfig({
    required this.principal,
    this.endpoints = StorachaEndpoints.production,
    this.defaultProvider = 'did:web:storacha.network',
  });

  /// The principal (signer) for this client
  ///
  /// This is the agent DID that will sign UCANs
  final Signer principal;

  /// Service endpoints
  final StorachaEndpoints endpoints;

  /// Default service provider DID
  final String defaultProvider;
}

