# storacha_dart

[![pub package](https://img.shields.io/pub/v/storacha_dart.svg)](https://pub.dev/packages/storacha_dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Dart/Flutter client library for [Storacha Network](https://storacha.network) (formerly web3.storage). Upload files to IPFS and Filecoin with ease, manage decentralized storage spaces, and retrieve content via IPFS gateways.

## Features

- 🔐 **Email-based authentication** - Simple login flow with email verification
- 📦 **Space management** - Create and manage isolated storage namespaces
- 📤 **File uploads** - Upload single files or entire directories
- 🌐 **Multi-platform** - iOS, Android, Web, Windows, macOS, Linux
- 📱 **Mobile-optimized** - Efficient memory usage, battery-aware, background uploads
- 🔑 **Injectable signers** - Bring your own key management (IPNS, HSM, Secure Enclave)
- 🔒 **Secure key storage** - Encrypted local storage for credentials
- 🎯 **Type-safe** - Full Dart type safety with null safety
- 🧪 **Well tested** - >80% code coverage

## 🎉 Storacha Network Support

### ✅ Current Status (v0.1.0+)

This package now includes **UCAN delegation support** and is **production-ready** for:
- ✅ Local IPFS nodes
- ✅ Custom storage providers
- ✅ Development and testing
- ✅ Content-addressable encoding
- ✅ **UCAN delegation loading** - Load delegations from Storacha CLI
- ✅ **Delegated uploads** - Upload to production Storacha network with delegations

### 🔜 Coming Soon

Additional features in development:
- 📡 **Space delegation API** - Programmatic space delegation without CLI (currently requires Storacha CLI)

### 💡 Using Delegations

Upload files to Storacha using delegations created by the Storacha CLI. Delegations allow you to grant specific permissions (like `space/blob/add` and `upload/add`) to an agent without sharing your account credentials.

#### Quick Start with Delegations

1. **Install Storacha CLI**: 
   ```bash
   npm install -g @storacha/cli
   ```

2. **Login and create a space**:
   ```bash
   storacha login your@email.com
   storacha space create my-app-space
   ```

3. **Get your agent DID** (from your Dart app):
   ```dart
   final agent = await Ed25519Signer.generate();
   print('Agent DID: ${agent.did().did()}');
   // Example output: did:key:z6MkqTtiRFtW67NtYNgGD5mGWCh3UJbYwLDNmXbQFjz4zqrz
   ```

4. **Create delegation** (choose one format):

   **Option A: Binary CAR format** (recommended):
   ```bash
   storacha delegation create <AGENT_DID> \
     --can 'space/blob/add' \
     --can 'upload/add' \
     --can 'space/index/add' \
     --output delegation.car
   ```

   **Option B: Base64 identity CID format**:
   ```bash
   storacha delegation create <AGENT_DID> \
     --can 'space/blob/add' \
     --can 'upload/add' \
     --can 'space/index/add' \
     --base64 > delegation.txt
   ```

5. **Use in your app**:
   ```dart
   // Load delegation (automatically detects format)
   final delegation = await Delegation.fromFile('delegation.car');
   
   // Use it with your client
   final config = StorachaConfig(
     principal: agent,
     delegations: [delegation],
   );
   final client = StorachaClient(config: config);
   ```

#### Supported Delegation Formats

The package automatically detects and parses both formats:

- **Binary CAR** (`.car`): IPLD CAR file containing the full UCAN proof chain
- **Base64 Identity CID** (`.txt`): Base64-encoded identity CID (multibase format)

Both formats work identically - use whichever is more convenient for your workflow.

#### Required Capabilities

For uploading files, you need these capabilities:
- `space/blob/add` - Add raw blobs to the space
- `upload/add` - Register DAG structures
- `space/index/add` - Index uploaded content (optional but recommended)

### 📚 New to Storacha? Start Here!

**Confused about delegations?** Read this first:

- 🎯 **[STORACHA_GUIDE.md](../STORACHA_GUIDE.md)** - Quick answer to your questions (5 min)
- 🚀 **[CLI Quick Start](docs/QUICKSTART_CLI.md)** - Upload files now (30 min)

**In French 🇫🇷** (English coming soon)

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

### Upload with delegations (Storacha CLI)

Use delegations created by Storacha CLI to upload to spaces you don't own. Supports both JWT and CAR formats:

```dart
import 'package:storacha_dart/storacha_dart.dart';

// 1. Load delegation from file (created by Storacha CLI)
final delegation = await Delegation.fromFile('delegation.ucan');

// 2. Create client with delegation
final agent = await Ed25519Signer.generate();
final config = ClientConfig(
  principal: agent,
  defaultProvider: 'did:web:up.storacha.network',
);

final client = StorachaClient(
  config,
  delegations: [delegation],
);

// 3. Add the delegated space
final spaceDid = delegation.capabilities.first.with_; // Extract space DID
final space = Space(
  did: spaceDid,
  name: 'Delegated Space',
  signer: agent,
  createdAt: DateTime.now(),
);

client.addSpace(space);
client.setCurrentSpace(spaceDid);

// 4. Upload files (proofs automatically included)
final cid = await client.uploadFile(
  MemoryFile(name: 'photo.jpg', bytes: photoBytes),
);

print('Uploaded! CID: $cid');
```

**Creating delegations with Storacha CLI:**

```bash
# Install CLI
npm install -g @storacha/cli

# Login and create space
storacha login your@email.com
storacha space create my-app

# Get your agent DID (from your Dart app)
# Then create delegation with the exact capabilities you need
storacha delegation create did:key:z6Mk... \
  -c space/blob/add \
  -c space/index/add \
  -c upload/add \
  --base64 > delegation.txt
```

The `--base64` flag outputs the delegation in a base64-encoded CAR format that includes the full proof chain. The package automatically handles this format when loading from file.

See `storacha_test_app/bin/upload_with_delegation.dart` for a complete working example.

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

## 📱 Mobile Performance

`storacha_dart` is specifically optimized for iOS and Android with:

### Memory Efficiency
- **Streaming architecture** - Files are processed in chunks (256 KiB), not loaded entirely in memory
- **Support for large files** - Upload multi-GB files without OutOfMemory errors
- **Adaptive chunking** - Smaller chunks on low-memory devices

```dart
// Efficient: streams by chunks
final blob = FileBlob(file);  // Only metadata in memory
await client.uploadFile(blob);

// Memory usage stays constant regardless of file size!
```

### Battery Optimization
- **Network-aware uploads** - Pause on cellular if preferred, continue on WiFi
- **Batch operations** - Group multiple small uploads to reduce wake-ups
- **Background processing** - Continue uploads when app is minimized

```dart
// Battery-friendly options
await client.uploadFile(
  blob,
  options: UploadFileOptions(
    preferWiFi: true,           // Pause on cellular
    pauseOnBatteryLow: true,    // Stop if battery < 20%
  ),
);
```

### Performance
- **Isolate support** - CPU-intensive operations (hashing, encoding) run in separate threads
- **Progress throttling** - UI updates limited to 60 FPS for smooth experience
- **Adaptive retries** - Exponential backoff on network failures

### Platform-Specific Features

**iOS**:
- Keychain integration for secure key storage
- Background fetch support for scheduled uploads
- Low Power Mode detection

**Android**:
- KeyStore integration for secure key storage
- WorkManager for reliable background uploads
- Foreground Service for visible long-running uploads

📖 **See [docs/PERFORMANCE.md](docs/PERFORMANCE.md) for detailed optimization guide**

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

