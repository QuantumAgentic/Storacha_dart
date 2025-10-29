# storacha_dart

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> ⚠️ **UNOFFICIAL & UNSTABLE VERSION**
> This is an **unofficial** Dart/Flutter implementation of the Storacha Network client. This package is **not yet stable** and is under active development. APIs may change without notice. Use at your own risk in production environments.

A Dart/Flutter client library for [Storacha Network](https://storacha.network) (formerly web3.storage). Upload files to IPFS and Filecoin with ease using UCAN delegations.

## ✨ Features

- 📦 **Space Management** - Create and manage isolated storage namespaces
- 📤 **File Uploads** - Upload files to IPFS/Filecoin via Storacha Network
- 🔑 **UCAN Delegation Support** - Work with delegations from Storacha CLI
- 🌐 **Multi-platform** - iOS, Android, Web, Windows, macOS, Linux
- 🎯 **Type-safe** - Full Dart type safety with null safety
- 📱 **Mobile-optimized** - Efficient memory usage and chunked uploads

## 🚨 Current Limitations

This package is **not yet production-ready**. Known limitations:

- **No email-based authentication** - You must use UCAN delegations from Storacha CLI
- **Temporary backend workaround** - Uses an optional backend proxy for reliable uploads (see Configuration section)
- **No directory uploads** - Only single file uploads are currently supported
- **Limited error handling** - Some edge cases may not be properly handled
- **Receipt handling incomplete** - Some Storacha receipts may not parse correctly

## 📋 Prerequisites

To use this package with the production Storacha Network, you need:

1. **Storacha CLI** installed and configured:
   ```bash
   npm install -g @storacha/cli
   storacha login your@email.com
   ```

2. **A Storacha space** created via the CLI:
   ```bash
   storacha space create my-app-space
   ```

3. **UCAN delegations** created for your app's agent DID (see Usage section)

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  storacha_dart: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## 🚀 Quick Start

### 1. Generate an Agent DID

Your app needs a unique identifier (DID) to receive delegations:

```dart
import 'package:storacha_dart/storacha_dart.dart';

// Generate a new agent (save this for later use!)
final agent = await Ed25519Signer.generate();
print('Agent DID: ${agent.did().did()}');
// Example output: did:key:z6MkqTtiRFtW67NtYNgGD5mGWCh3UJbYwLDNmXbQFjz4zqrz
```

**Important:** Save the agent's private key securely. You'll need it each time your app runs.

### 2. Create a Delegation

Use the Storacha CLI to delegate permissions to your agent:

```bash
# Create delegation with required capabilities
storacha delegation create <YOUR_AGENT_DID> \
  --can 'space/blob/add' \
  --can 'upload/add' \
  --can 'space/index/add' \
  --output delegation.car
```

This creates a `delegation.car` file that grants your agent permission to upload to your space.

### 3. Upload Files

Load the delegation and upload files:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:storacha_dart/storacha_dart.dart';

// Load the delegation
final delegation = await Delegation.fromFile('delegation.car');

// Create client configuration
final agent = await Ed25519Signer.generate(); // Or load your saved agent
final config = ClientConfig(
  principal: agent,
  defaultProvider: 'did:web:up.storacha.network',
);

// Initialize client with delegation
final client = StorachaClient(config, delegations: [delegation]);

// Extract space DID from delegation
final spaceDid = delegation.capabilities.first.with_;

// Add and select the space
final space = Space(
  did: spaceDid,
  name: 'My Space',
  signer: agent,
  createdAt: DateTime.now(),
);
client.addSpace(space);
client.setCurrentSpace(spaceDid);

// Upload a file
final file = MemoryFile(
  name: 'hello.txt',
  bytes: Uint8List.fromList('Hello, Storacha!'.codeUnits),
);

final cid = await client.uploadFile(file);
print('Uploaded! CID: $cid');
print('View at: https://w3s.link/ipfs/$cid');

// Clean up
client.close();
```

## 📖 Core Concepts

### Spaces

A **space** is an isolated storage namespace in Storacha. Each space has:
- A unique DID (Decentralized Identifier)
- Its own storage quota
- Independent access control via UCAN delegations

Create a space via the Storacha CLI:
```bash
storacha space create my-app-space
```

### UCAN Delegations

**UCAN (User Controlled Authorization Network)** is a decentralized authorization system. Instead of sharing your credentials, you create **delegations** that grant specific permissions to other DIDs.

Required capabilities for uploads:
- `space/blob/add` - Upload raw data blobs
- `upload/add` - Register uploaded content
- `space/index/add` - Create searchable indexes

### Content Addressing (CID)

Files are identified by their **CID (Content Identifier)**:
- CIDs are derived from file content using cryptographic hashing
- Same content always produces the same CID
- CIDs are universally unique and verifiable

Access uploaded files via IPFS gateways:
```
https://w3s.link/ipfs/<CID>
https://ipfs.io/ipfs/<CID>
```

## ⚙️ Configuration

### Basic Configuration

```dart
final config = ClientConfig(
  principal: agent,                                 // Your agent's signer
  defaultProvider: 'did:web:up.storacha.network',   // Storacha service DID
);
```

### Backend Workaround (TEMPORARY)

> ⚠️ **Temporary Solution**: This workaround ensures immediate IPFS retrieval while native receipt handling is being finalized.

If you experience issues with IPFS retrieval after upload, you can use a backend proxy:

```dart
final config = ClientConfig(
  principal: agent,
  defaultProvider: 'did:web:up.storacha.network',
  backendUrl: 'https://your-backend.vercel.app',  // Optional backend proxy
);
```

The backend acts as a bridge to the official JavaScript client. This workaround will be removed in future versions once the native Dart flow is fully stable.

### Upload Options

```dart
final options = UploadFileOptions(
  chunkSize: 256 * 1024,  // 256 KiB chunks (default)
  onUploadProgress: (status) {
    print('Progress: ${status.percentage?.toStringAsFixed(1)}%');
  },
);

final cid = await client.uploadFile(file, options: options);
```

## 📝 Examples

See the `example/` directory for complete examples:

- **[delegation_example.dart](example/delegation_example.dart)** - UCAN delegation workflow
- **[upload_example.dart](example/upload_example.dart)** - File upload examples

Run examples:
```bash
dart run example/delegation_example.dart
dart run example/upload_example.dart
```

## 🏗️ Architecture

The package is organized into modules:

```
lib/src/
├── client/          # Main client and configuration
├── crypto/          # Signers and DID generation (Ed25519)
├── ipfs/            # IPFS data structures (CID, CAR, UnixFS)
├── ucan/            # UCAN delegation and invocation
├── transport/       # HTTP communication with Storacha
├── upload/          # Upload logic and blob handling
└── filecoin/        # Filecoin piece CID calculation
```

## 🧪 Testing

Run tests:
```bash
dart test
```

Run integration tests (requires valid delegation):
```bash
dart test test/integration/
```

## 🛠️ Development Status

| Feature | Status | Notes |
|---------|--------|-------|
| UCAN delegations | ✅ Working | CAR and base64 formats supported |
| Single file upload | ✅ Working | With temporary backend workaround |
| Space management | ✅ Working | Local space management |
| Progress tracking | ✅ Working | Chunked upload progress |
| Directory upload | ⏳ Planned | Not yet implemented |
| Email authentication | ⏳ Planned | Use Storacha CLI for now |
| Receipt handling | 🔧 In Progress | Some edge cases remain |
| IPFS retrieval | 🔧 In Progress | Backend workaround available |

## 🤝 Contributing

This is an unofficial package developed by QuantumAgentic. Contributions are welcome!

To contribute:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

Please note that APIs may change significantly as the package stabilizes.

## 📄 License

MIT License with trademark restriction - see [LICENSE](LICENSE) file.

The name "QuantumAgentic" and associated trademarks may not be used to endorse products derived from this software without permission.

## 🔗 Resources

- [Storacha Network](https://storacha.network/)
- [Storacha Documentation](https://docs.storacha.network/)
- [Storacha CLI](https://www.npmjs.com/package/@storacha/cli)
- [UCAN Specification](https://github.com/ucan-wg/spec)
- [IPFS Documentation](https://docs.ipfs.tech/)

## ⚠️ Disclaimer

This is an **unofficial** implementation and is **not affiliated with or endorsed by Storacha Network or Protocol Labs**. This package is provided "as-is" without warranty. Use in production at your own risk.

For official Storacha clients, see:
- [Official JavaScript Client](https://github.com/storacha/w3up)

---

Made with ❤️ by the QuantumAgentic team
