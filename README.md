# storacha_dart

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Development Status](https://img.shields.io/badge/status-active%20development-blue.svg)](https://github.com/QuantumAgentic/storacha_dart)

A Dart/Flutter client library for [Storacha Network](https://storacha.network) (formerly web3.storage). Upload files to IPFS and Filecoin with ease using UCAN delegations.

> **Note:** This package is under active development. APIs may change as new features are added and the implementation is refined. Check the [Development Status](#-development-status) section for current capabilities.

## ✨ Features

- 📦 **Space Management** - Create and manage isolated storage namespaces
- 📤 **File Uploads** - Upload files to IPFS/Filecoin via Storacha Network
- 🔑 **UCAN Delegation Support** - Work with delegations from Storacha CLI
- 🌐 **Multi-platform** - iOS, Android, Web, Windows, macOS, Linux
- 🎯 **Type-safe** - Full Dart type safety with null safety
- 📱 **Mobile-optimized** - Efficient memory usage and chunked uploads

## 🚧 Current Implementation

Current implementation status:

- ✅ **UCAN delegation support** - Full support for delegations from Storacha CLI
- ✅ **Single file uploads** - Upload files to IPFS/Filecoin
- ✅ **Parallel batch uploads** - Upload up to 50 files concurrently with optimized polling
- ✅ **Space management** - Create and manage storage spaces
- ✅ **Progress tracking** - Per-file and aggregated progress for batch uploads
- 🔧 **Backend workaround available** - Optional backend proxy for enhanced reliability (see Configuration section)
- 📋 **In progress** - Email-based authentication (use Storacha CLI delegations for now)
- 📋 **Planned** - Directory uploads as unified DAG structures

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

> **Note:** This package is not yet published to pub.dev. Install directly from GitHub.

Add to your `pubspec.yaml`:

```yaml
dependencies:
  storacha_dart:
    git:
      url: https://github.com/QuantumAgentic/storacha_dart.git
      ref: main  # or specify a tag/commit for stability
```

Then run:

```bash
flutter pub get
```

### Installing a Specific Version

For production use, it's recommended to pin to a specific commit or tag:

```yaml
dependencies:
  storacha_dart:
    git:
      url: https://github.com/QuantumAgentic/storacha_dart.git
      ref: 9050c9b  # Specific commit hash
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

### Parallel Batch Uploads

Upload multiple files concurrently with optimized performance:

```dart
final files = [
  MemoryFile(name: 'photo1.jpg', bytes: photo1Bytes),
  MemoryFile(name: 'photo2.jpg', bytes: photo2Bytes),
  MemoryFile(name: 'photo3.jpg', bytes: photo3Bytes),
];

final results = await client.uploadFiles(
  files,
  maxConcurrent: 10,  // Upload up to 10 files simultaneously
  onProgress: (loaded, total) {
    print('Overall: ${(loaded / total * 100).toStringAsFixed(1)}%');
  },
  onFileComplete: (filename, cid) {
    print('✓ $filename: $cid');
  },
  onFileError: (filename, error) {
    print('✗ $filename failed: $error');
  },
);

print('Uploaded ${results.length} files successfully');
```

**Performance:** Optimized polling intervals (500ms) and timeouts (5s) provide 8-10x faster uploads compared to sequential processing.

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
| Batch parallel uploads | ✅ Working | Up to 50 files concurrently, 8-10x faster |
| Space management | ✅ Working | Local space management |
| Progress tracking | ✅ Working | Per-file and aggregated progress |
| Optimized polling | ✅ Working | 500ms intervals, 5s timeouts |
| Directory upload | ⏳ Planned | Unified DAG structure |
| Email authentication | ⏳ Planned | Use Storacha CLI for now |
| Receipt handling | 🔧 In Progress | Some edge cases remain |
| IPFS retrieval | 🔧 In Progress | Backend workaround available |

## 🤝 Contributing

Contributions are welcome! This package is actively maintained by QuantumAgentic.

To contribute:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

Please note that APIs may evolve as new features are added and the implementation is refined.

## 📄 License

MIT License with trademark restriction - see [LICENSE](LICENSE) file.

The name "QuantumAgentic" and associated trademarks may not be used to endorse products derived from this software without permission.

## 🔗 Resources

- [Storacha Network](https://storacha.network/)
- [Storacha Documentation](https://docs.storacha.network/)
- [Storacha CLI](https://www.npmjs.com/package/@storacha/cli)
- [UCAN Specification](https://github.com/ucan-wg/spec)
- [IPFS Documentation](https://docs.ipfs.tech/)

## 📝 About

This is a community-driven Dart/Flutter implementation for Storacha Network. This package is not affiliated with or endorsed by Storacha Network or Protocol Labs.

For the official JavaScript implementation:
- [Official Upload Service](https://github.com/storacha/upload-service)

---

Made with ❤️ by the QuantumAgentic team
