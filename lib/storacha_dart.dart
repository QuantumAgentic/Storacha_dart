/// Storacha Dart Client Library
///
/// A Dart/Flutter client for Storacha Network (IPFS/Filecoin storage).
library storacha_dart;

// Export cryptography utilities
export 'src/crypto/did.dart';
export 'src/crypto/ed25519_key_pair.dart';
export 'src/crypto/signer.dart';

// Export IPFS multiformats utilities (internal for now, will be hidden later)
export 'src/ipfs/multiformats/cid.dart';
export 'src/ipfs/multiformats/multibase.dart';
export 'src/ipfs/multiformats/multihash.dart';
export 'src/ipfs/multiformats/varint.dart';

// Export UCAN utilities
export 'src/ucan/capability.dart';
export 'src/ucan/ucan.dart';

// Export client
export 'src/client/client_config.dart';
export 'src/client/space.dart';
export 'src/client/storacha_client.dart';
