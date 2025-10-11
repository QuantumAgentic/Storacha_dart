/// Storacha Dart Client Library
///
/// A Dart/Flutter client for Storacha Network (IPFS/Filecoin storage).
library storacha_dart;

// Export client
export 'src/client/client_config.dart';
export 'src/client/space.dart';
export 'src/client/storacha_client.dart';

// Export core utilities
export 'src/core/network_retry.dart';

// Export cryptography utilities
export 'src/crypto/did.dart';
export 'src/crypto/ed25519_key_pair.dart';
export 'src/crypto/signer.dart';

// Export IPFS CAR utilities
export 'src/ipfs/car/car_encoder.dart';
export 'src/ipfs/car/car_types.dart';

// Export IPFS multiformats utilities (internal for now, will be hidden later)
export 'src/ipfs/multiformats/cid.dart';
export 'src/ipfs/multiformats/multibase.dart';
export 'src/ipfs/multiformats/multihash.dart';
export 'src/ipfs/multiformats/varint.dart';

// Export IPFS UnixFS utilities
export 'src/ipfs/unixfs/file_chunker.dart';
export 'src/ipfs/unixfs/protobuf_encoder.dart';
export 'src/ipfs/unixfs/unixfs_encoder.dart';
export 'src/ipfs/unixfs/unixfs_types.dart';

// Export network transport
export 'src/transport/storacha_transport.dart';

// Export UCAN utilities
export 'src/ucan/capability.dart';
export 'src/ucan/capability_types.dart';
export 'src/ucan/invocation.dart';
export 'src/ucan/ucan.dart';

// Export upload utilities
export 'src/upload/blob.dart';
export 'src/upload/progress_throttle.dart';
export 'src/upload/upload_options.dart';
