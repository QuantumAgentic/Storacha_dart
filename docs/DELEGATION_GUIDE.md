# Delegation Guide

This guide explains how to use UCAN delegations with `storacha_dart` to upload files to Storacha Network.

## What are Delegations?

Delegations are cryptographic proofs that grant specific permissions to an agent (identified by a DID) without sharing your account credentials. Think of them as "permission tokens" that you can give to apps or services.

### Key Concepts

- **Space**: An isolated storage namespace that you own
- **Agent**: A cryptographic identity (DID) that can perform actions
- **Capabilities**: Specific permissions like `space/blob/add` or `upload/add`
- **Delegation**: A signed proof that grants capabilities to an agent
- **UCAN**: User Controlled Authorization Network - the protocol behind delegations

## Prerequisites

1. **Storacha CLI**: Install the official CLI
   ```bash
   npm install -g @storacha/cli
   ```

2. **Storacha Account**: Create a free account
   ```bash
   storacha login your@email.com
   ```

3. **Space**: Create a storage space
   ```bash
   storacha space create my-app-space
   ```

## Step-by-Step Guide

### Step 1: Generate an Agent

In your Dart app, generate a new agent:

```dart
import 'package:storacha_dart/storacha_dart.dart';
import 'dart:convert';

Future<void> main() async {
  // Generate a new agent
  final agent = await Ed25519Signer.generate();
  
  // Get the DID
  final agentDid = agent.did().did();
  print('Agent DID: $agentDid');
  
  // Export the private key for later use
  final privateKey = await agent.export();
  final privateKeyBase64 = base64.encode(privateKey);
  print('Private Key (save this!): $privateKeyBase64');
}
```

Output example:
```
Agent DID: did:key:z6MkqTtiRFtW67NtYNgGD5mGWCh3UJbYwLDNmXbQFjz4zqrz
Private Key (save this!): bJ6u266uBtJxMEeGgWAJPPAwRre3HUibylOoG7QWFFA=
```

**⚠️ Important**: Save the private key securely! You'll need it to load the agent later.

### Step 2: Create a Delegation

Using the Storacha CLI, create a delegation for your agent:

#### Option A: Binary CAR Format (Recommended)

```bash
storacha delegation create did:key:z6MkqTtiRFtW67NtYNgGD5mGWCh3UJbYwLDNmXbQFjz4zqrz \
  --can 'space/blob/add' \
  --can 'upload/add' \
  --can 'space/index/add' \
  --output delegation.car
```

This creates a binary CAR file containing the full UCAN proof chain.

#### Option B: Base64 Identity CID Format

```bash
storacha delegation create did:key:z6MkqTtiRFtW67NtYNgGD5mGWCh3UJbYwLDNmXbQFjz4zqrz \
  --can 'space/blob/add' \
  --can 'upload/add' \
  --can 'space/index/add' \
  --base64 > delegation.txt
```

This creates a text file with a base64-encoded identity CID.

**Which format to use?**
- **CAR format**: More compact, standard IPLD format
- **Base64 format**: Easier to copy/paste, works well with CI/CD pipelines

Both formats work identically - the package automatically detects which one you're using.

### Step 3: Use the Delegation in Your App

#### Load the Agent

```dart
import 'package:storacha_dart/storacha_dart.dart';
import 'dart:convert';

// Load the agent from the saved private key
const privateKeyBase64 = 'bJ6u266uBtJxMEeGgWAJPPAwRre3HUibylOoG7QWFFA=';
final privateKey = base64.decode(privateKeyBase64);
final agent = await Ed25519Signer.import(privateKey);

print('Agent DID: ${agent.did().did()}');
```

#### Load the Delegation

```dart
import 'dart:io';

// The package automatically detects the format
final delegationFile = File('delegation.car'); // or 'delegation.txt'
final delegationBytes = await delegationFile.readAsBytes();
final delegation = Delegation.fromCarBytes(delegationBytes);

// Or use the convenience method
final delegation = await Delegation.fromFile('delegation.car');

print('Delegation loaded!');
print('Issuer: ${delegation.ucan.issuer}');
print('Audience: ${delegation.ucan.audience}');
print('Capabilities: ${delegation.ucan.capabilities.length}');
```

#### Verify the Delegation

```dart
// Extract the space DID from the delegation
final spaceDid = delegation.ucan.capabilities.first.with_;

// Verify the agent matches the delegation audience
if (delegation.ucan.audience != agent.did().did()) {
  throw Exception('Agent DID does not match delegation audience!');
}

print('✅ Delegation verified for space: $spaceDid');
```

#### Configure the Client

```dart
// Create client configuration
final config = StorachaConfig(
  principal: agent,
  delegations: [delegation],
);

// Create the client
final client = StorachaClient(config: config);

// Set the current space
client.setCurrentSpace(spaceDid);

print('✅ Client ready to upload!');
```

#### Upload Files

```dart
import 'dart:typed_data';

// Create test data
final testData = Uint8List.fromList(utf8.encode('Hello, Storacha!'));

// Upload to the delegated space
final result = await client.uploadFile(
  fileName: 'hello.txt',
  data: testData,
);

print('🎉 Upload successful!');
print('CID: ${result.root}');
print('Gateway URL: https://w3s.link/ipfs/${result.root}');
```

## Complete Example

Here's a complete working example:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:storacha_dart/storacha_dart.dart';

Future<void> main() async {
  // 1. Load agent
  const agentKeyBase64 = 'YOUR_PRIVATE_KEY_HERE';
  final agentKey = base64.decode(agentKeyBase64);
  final agent = await Ed25519Signer.import(agentKey);
  
  print('🔑 Agent DID: ${agent.did().did()}');

  // 2. Load delegation
  final delegation = await Delegation.fromFile('delegation.car');
  
  print('📁 Delegation loaded');
  print('   Issuer: ${delegation.ucan.issuer}');
  print('   Audience: ${delegation.ucan.audience}');
  
  // 3. Extract space DID
  final spaceDid = delegation.ucan.capabilities.first.with_;
  print('🔍 Space DID: $spaceDid');

  // 4. Create client
  final config = StorachaConfig(
    principal: agent,
    delegations: [delegation],
  );
  final client = StorachaClient(config: config);
  client.setCurrentSpace(spaceDid);
  
  print('✅ Client ready');

  // 5. Upload file
  final testData = Uint8List.fromList(
    utf8.encode('Hello from storacha_dart!')
  );
  
  print('📤 Uploading...');
  final result = await client.uploadFile(
    fileName: 'test.txt',
    data: testData,
  );

  print('🎉 SUCCESS!');
  print('   CID: ${result.root}');
  print('   URL: https://w3s.link/ipfs/${result.root}');
}
```

## Troubleshooting

### Error: "Agent DID does not match delegation audience"

**Cause**: You're using a different agent than the one the delegation was created for.

**Solution**: Make sure you're using the same private key that corresponds to the DID you used when creating the delegation.

```dart
// Check the DIDs
print('Agent DID: ${agent.did().did()}');
print('Delegation audience: ${delegation.ucan.audience}');
// These must match!
```

### Error: "Invalid response: missing 'ok' or 'report' field"

**Cause**: The delegation might not have the required capabilities.

**Solution**: Recreate the delegation with all necessary capabilities:

```bash
storacha delegation create <AGENT_DID> \
  --can 'space/blob/add' \
  --can 'upload/add' \
  --can 'space/index/add' \
  --output delegation.car
```

### Error: "FormatException: Invalid CID"

**Cause**: The delegation file might be corrupted or in an unsupported format.

**Solution**: 
1. Regenerate the delegation with the Storacha CLI
2. Make sure you're using one of the two supported formats (CAR or base64)
3. Check that the file wasn't modified or truncated

## Security Best Practices

1. **Keep private keys secure**: Never commit them to version control
2. **Use environment variables**: Store keys in `.env` files (add to `.gitignore`)
3. **Rotate keys regularly**: Generate new agents periodically
4. **Limit capabilities**: Only grant the minimum required permissions
5. **Monitor usage**: Check your Storacha dashboard for unexpected activity

## Advanced: Multiple Delegations

You can use multiple delegations for different spaces:

```dart
// Load multiple delegations
final delegation1 = await Delegation.fromFile('delegation1.car');
final delegation2 = await Delegation.fromFile('delegation2.car');

// Configure client with all delegations
final config = StorachaConfig(
  principal: agent,
  delegations: [delegation1, delegation2],
);

final client = StorachaClient(config: config);

// Switch between spaces
client.setCurrentSpace(spaceDid1);
await client.uploadFile(/* ... */); // Uses delegation1

client.setCurrentSpace(spaceDid2);
await client.uploadFile(/* ... */); // Uses delegation2
```

## Next Steps

- [Full API Documentation](API.md)
- [Storacha CLI Reference](https://docs.storacha.network/cli/)
- [UCAN Specification](https://github.com/ucan-wg/spec)
- [Example Applications](../example/)

## Need Help?

- 💬 [GitHub Issues](https://github.com/your-repo/storacha_dart/issues)
- 📚 [Storacha Docs](https://docs.storacha.network/)
- 🐦 [Storacha Twitter](https://twitter.com/storacha_network)

