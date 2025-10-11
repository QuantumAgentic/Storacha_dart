/// Example demonstrating file upload to Storacha Network
///
/// This example shows how to:
/// 1. Create a client with authentication
/// 2. Create and manage storage spaces
/// 3. Upload files with progress tracking
/// 4. Handle upload results
///
/// Run with: dart run example/upload_example.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/storacha_dart.dart';

Future<void> main() async {
  print('🚀 Storacha Dart Client Example\n');

  // ========================================
  // Step 1: Create Client
  // ========================================
  print('1️⃣  Creating client...');

  // Generate a new Ed25519 key pair for authentication
  final signer = await Ed25519Signer.generate();

  // Create client configuration
  final config = ClientConfig(
    principal: signer,
    endpoints: StorachaEndpoints.production,
  );

  // Initialize client
  final client = StorachaClient(config);

  print('   ✓ Client DID: ${client.did()}');
  print('   ✓ Service: ${config.endpoints.serviceUrl}\n');

  // ========================================
  // Step 2: Create Space
  // ========================================
  print('2️⃣  Creating storage space...');

  final space = await client.createSpace('My Photos');

  print('   ✓ Space created: ${space.name}');
  print('   ✓ Space DID: ${space.did}');
  print('   ✓ Current space: ${client.currentSpace()?.name}\n');

  // ========================================
  // Step 3: Upload Small File
  // ========================================
  print('3️⃣  Uploading small file...');

  final textFile = MemoryFile(
    name: 'hello.txt',
    bytes: Uint8List.fromList(
      utf8.encode('Hello, Storacha! This is a test upload.'),
    ),
  );

  final textCid = await client.uploadFile(textFile);

  print('   ✓ File uploaded successfully!');
  print('   ✓ CID: $textCid');
  print('   ✓ Gateway URL: https://w3s.link/ipfs/$textCid\n');

  // ========================================
  // Step 4: Upload File with Progress
  // ========================================
  print('4️⃣  Uploading file with progress tracking...');

  // Create a larger file (500 KB)
  final largeFile = MemoryFile(
    name: 'image.jpg',
    bytes: Uint8List.fromList(
      List.generate(500 * 1024, (i) => i % 256),
    ),
  );

  // Configure upload options with progress callback
  final uploadOptions = UploadFileOptions(
    chunkSize: 256 * 1024, // 256 KiB chunks
    onUploadProgress: (status) {
      final percentage = status.percentage?.toStringAsFixed(1) ?? '0.0';
      final loaded = _formatBytes(status.loaded ?? 0);
      final total = _formatBytes(status.total ?? 0);
      print('   📊 Progress: $percentage% ($loaded / $total)');
    },
  );

  final imageCid = await client.uploadFile(
    largeFile,
    options: uploadOptions,
  );

  print('   ✓ Large file uploaded!');
  print('   ✓ CID: $imageCid');
  print('   ✓ Gateway URL: https://w3s.link/ipfs/$imageCid\n');

  // ========================================
  // Step 5: Upload Multiple Files
  // ========================================
  print('5️⃣  Uploading batch of files...');

  final files = [
    MemoryFile(
      name: 'config.json',
      bytes: Uint8List.fromList(
        utf8.encode('{"version": "1.0", "name": "my-app"}'),
      ),
    ),
    MemoryFile(
      name: 'data.csv',
      bytes: Uint8List.fromList(
        utf8.encode('name,value\nAlice,100\nBob,200'),
      ),
    ),
  ];

  print('   Uploading ${files.length} files...');
  final uploadedFiles = <String, CID>{};

  for (final file in files) {
    final cid = await client.uploadFile(file);
    uploadedFiles[file.name] = cid;
    print('   ✓ ${file.name}: $cid');
  }

  print('   ✓ Batch upload complete!\n');

  // ========================================
  // Step 6: Demonstrate Content Addressing
  // ========================================
  print('6️⃣  Demonstrating content-addressability...');

  // Upload same content twice
  final content = utf8.encode('Identical content');
  final file1 = MemoryFile(name: 'file1.txt', bytes: content);
  final file2 = MemoryFile(name: 'file2.txt', bytes: content);

  final cid1 = await client.uploadFile(file1);
  final cid2 = await client.uploadFile(file2);

  print('   File 1 CID: $cid1');
  print('   File 2 CID: $cid2');
  print('   ✓ CIDs are identical: ${cid1 == cid2}');
  print('   ℹ️  Same content always produces the same CID!\n');

  // ========================================
  // Step 7: Multiple Spaces
  // ========================================
  print('7️⃣  Managing multiple spaces...');

  final workSpace = await client.createSpace('Work Documents');
  print('   ✓ Created space: ${workSpace.name}');

  print('   Available spaces:');
  for (final s in client.spaces()) {
    final indicator = s.did == client.currentSpace()?.did ? '→' : ' ';
    print('   $indicator ${s.name} (${s.did.substring(0, 20)}...)');
  }

  // Switch spaces
  client.setCurrentSpace(workSpace.did);
  print('   ✓ Switched to: ${client.currentSpace()?.name}\n');

  // ========================================
  // Step 8: Cleanup
  // ========================================
  print('8️⃣  Cleaning up...');

  client.close();
  print('   ✓ Client closed\n');

  // ========================================
  // Summary
  // ========================================
  print('═' * 50);
  print('✨ Summary');
  print('═' * 50);
  print('Spaces created: ${client.spaces().length}');
  print('Files uploaded: ${3 + uploadedFiles.length}');
  print('Total CIDs:     ${uploadedFiles.length + 3}');
  print('\n🎉 All operations completed successfully!');
  print('\nTo retrieve your files:');
  print('  https://w3s.link/ipfs/<CID>');
  print('\nLearn more at: https://storacha.network');
}

/// Format bytes to human-readable string
String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}


