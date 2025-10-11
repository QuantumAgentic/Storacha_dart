# storacha_dart

[![pub package](https://img.shields.io/pub/v/storacha_dart.svg)](https://pub.dev/packages/storacha_dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Dart/Flutter client library for [Storacha Network](https://storacha.network) (formerly web3.storage). Upload files to IPFS and Filecoin with ease, manage decentralized storage spaces, and retrieve content via IPFS gateways.

## Features

- 🔐 **Email-based authentication** - Simple login flow with email verification
- 📦 **Space management** - Create and manage isolated storage namespaces
- 📤 **File uploads** - Upload single files or entire directories
- 🌐 **Multi-platform** - iOS, Android, Web, Windows, macOS, Linux
- 🔑 **Injectable signers** - Bring your own key management (IPNS, HSM, Secure Enclave)
- 🔒 **Secure key storage** - Encrypted local storage for credentials
- 🎯 **Type-safe** - Full Dart type safety with null safety
- 🧪 **Well tested** - >80% code coverage

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  storacha_dart: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Create a client

```dart
import 'package:storacha_dart/storacha_dart.dart';

final client = await StorachaClient.create();
```

### 2. Login with email

```dart
final account = await client.login('your-email@example.com');

// Wait for payment plan selection (required for new accounts)
await account.plan.wait();
```

### 3. Create a space

```dart
final space = await client.createSpace(
  'my-awesome-space',
  account: account,
);
```

### 4. Upload files

```dart
// Upload a single file
final bytes = await File('document.pdf').readAsBytes();
final cid = await client.uploadFile(
  bytes,
  filename: 'document.pdf',
);

print('File uploaded! CID: $cid');
print('Gateway URL: ${client.getGatewayUrl(cid)}');

// Upload a directory
final files = [
  StorachaFile(
    content: readmeBytes,
    path: 'readme.md',
  ),
  StorachaFile(
    content: mainPyBytes,
    path: 'src/main.py',
  ),
  StorachaFile(
    content: imageBytes,
    path: 'images/logo.png',
  ),
];

final dirCid = await client.uploadDirectory(files);
print('Directory uploaded! CID: $dirCid');
```

## Usage Examples

### Upload with progress tracking

```dart
final cid = await client.uploadFile(
  largeFileBytes,
  filename: 'video.mp4',
  onProgress: (sent, total) {
    final percent = (sent / total * 100).toStringAsFixed(1);
    print('Upload progress: $percent%');
  },
);
```

### Manage multiple spaces

```dart
// Create multiple spaces
final personalSpace = await client.createSpace('personal');
final workSpace = await client.createSpace('work');

// Switch between spaces
await client.setCurrentSpace(personalSpace.did);
// ... upload to personal space

await client.setCurrentSpace(workSpace.did);
// ... upload to work space

// List all spaces
final spaces = await client.listSpaces();
for (final space in spaces) {
  print('Space: ${space.name} (${space.did})');
}
```

### 🔑 Use external signers (IPNS keys, HSM, Secure Enclave)

One of the key features of `storacha_dart` is the ability to inject your own key management system, keeping private keys secure within your app:

```dart
// Example: Use your existing IPNS keys with Storacha
class MyIPNSSigner implements Signer {
  final String _did;
  final MyKeyManager _keyManager; // Your app's key manager
  
  MyIPNSSigner(this._did, this._keyManager);
  
  @override
  String get did => _did;
  
  @override
  Future<Uint8List> sign(Uint8List message) async {
    // Private key never leaves your key manager
    return await _keyManager.signWithIPNSKey(message);
  }
}

// Option 1: Use custom signer for the entire client
final ipnsSigner = MyIPNSSigner(myDID, myKeyManager);
final client = await StorachaClient.create(
  config: ClientConfig(
    signer: ipnsSigner, // All operations use your IPNS keys
  ),
);

// Option 2: Use different signers for different spaces
final personalSpace = await client.createSpace('personal'); // Default signer
final ipnsSpace = await client.createSpace(
  'ipns-space',
  signer: ipnsSigner, // This space uses your IPNS keys
);

// Uploads automatically use the correct signer
await client.setCurrentSpace(ipnsSpace.did);
await client.uploadFile(data); // Signed with your IPNS keys
```

**Benefits:**
- 🔒 **Security**: Private keys never exposed to the package
- 🔑 **Flexibility**: Use HSM, Secure Enclave, or any custom key storage
- 🔄 **Reuse**: Integrate with existing IPNS keys, crypto wallets, etc.

### Custom gateway configuration

```dart
final space = await client.createSpace(
  'my-space',
  account: account,
  authorizeGatewayServices: [customGateway],
);

// Or skip gateway authorization entirely
final privateSpace = await client.createSpace(
  'private-space',
  account: account,
  skipGatewayAuthorization: true,
);
```

### Error handling

```dart
try {
  final cid = await client.uploadFile(fileBytes);
} on StorachaAuthException catch (e) {
  print('Authentication error: $e');
} on StorachaNetworkException catch (e) {
  print('Network error: $e');
} on StorachaException catch (e) {
  print('General error: $e');
}
```

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| Android  | ✅ | API level 21+ |
| iOS      | ✅ | iOS 12+ |
| Web      | ✅ | All modern browsers |
| Windows  | ✅ | Windows 10+ |
| macOS    | ✅ | macOS 10.14+ |
| Linux    | ✅ | Ubuntu 18.04+ |

## Architecture

The package is organized into several modules:

- **Client** - Main API interface
- **Models** - Data structures (Space, Account, CID, etc.)
- **Services** - Business logic (Auth, Upload, Space management)
- **Storage** - Secure local storage for keys
- **Crypto** - DID and UCAN implementation
- **Transport** - HTTP communication and CAR encoding

## Security

- **DID (Decentralized Identifiers)** - Keys generated locally using Ed25519
- **UCAN (User Controlled Authorization Network)** - JWT-based authorization
- **Secure Storage** - Keys stored in Keychain (iOS) or KeyStore (Android)
- **Recovery** - Optional account-based recovery for multi-device access

## Testing

Run all tests:

```bash
dart test
```

Run with coverage:

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## Contributing

Contributions are welcome! Please read our [contributing guide](CONTRIBUTING.md) first.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Resources

- [Storacha Documentation](https://docs.storacha.network/)
- [Storacha JS Client](https://docs.storacha.network/js-client/)
- [IPFS Documentation](https://docs.ipfs.tech/)
- [UCAN Specification](https://github.com/ucan-wg/spec)

## Credits

Based on the official [Storacha JavaScript client](https://github.com/storacha/storacha).

---

Made with ❤️ by the CasterCorp team

