import 'package:test/test.dart';

/// Documentation for using delegations created by Storacha CLI
///
/// This test file documents the workflow for creating and using delegations
/// with the Storacha CLI and this Dart package.
void main() {
  group('Storacha CLI Delegation Format', () {
    test('documents the complete delegation workflow', () {
      // This test documents how to use delegations created by the Storacha CLI
      
      // ============================================================================
      // STEP 1: Install Storacha CLI
      // ============================================================================
      // npm install -g @storacha/cli
      
      // ============================================================================
      // STEP 2: Login and create a space
      // ============================================================================
      // storacha login your@email.com
      // storacha space create my-app
      
      // ============================================================================
      // STEP 3: Generate your app's agent DID in Dart
      // ============================================================================
      // import 'package:storacha_dart/storacha_dart.dart';
      // 
      // final agent = await Ed25519Signer.generate();
      // print('Agent DID: ${agent.did().did()}');
      // // Outputs something like: did:key:z6Mk...
      
      // ============================================================================
      // STEP 4: Create delegation using Storacha CLI
      // ============================================================================
      // storacha delegation create did:key:z6Mk... \
      //   -c space/blob/add \
      //   -c space/index/add \
      //   -c upload/add \
      //   --base64 > delegation.txt
      //
      // The --base64 flag outputs a base64-encoded CAR file containing the
      // delegation and its proof chain. The output starts with 'm' (multibase prefix).
      
      // ============================================================================
      // STEP 5: Load and use delegation in your Dart app
      // ============================================================================
      // import 'package:storacha_dart/storacha_dart.dart';
      // import 'dart:io';
      //
      // // Load delegation
      // final delegation = await Delegation.fromFile('delegation.txt');
      // 
      // // The package automatically handles:
      // // - Multibase 'm' prefix removal
      // // - Base64 decoding
      // // - CAR archive parsing
      // // - UCAN extraction from proof chain
      //
      // // Create client with delegation
      // final agent = await Ed25519Signer.generate(); // or load your saved key
      // final config = ClientConfig(
      //   principal: agent,
      //   defaultProvider: 'did:web:up.storacha.network',
      // );
      //
      // final client = StorachaClient(
      //   config,
      //   delegations: [delegation],
      // );
      //
      // // Extract space DID from delegation
      // final spaceDid = delegation.capabilities.first.with_;
      //
      // // Add the delegated space
      // final space = Space(
      //   did: spaceDid,
      //   name: 'Delegated Space',
      //   signer: agent,
      //   createdAt: DateTime.now(),
      // );
      //
      // client.addSpace(space);
      // client.setCurrentSpace(spaceDid);
      //
      // // Upload files (delegation proofs are automatically included)
      // final cid = await client.uploadFile(
      //   MemoryFile(name: 'photo.jpg', bytes: photoBytes),
      // );
      //
      // print('Uploaded! CID: $cid');
      
      expect(true, isTrue); // Documentation test
    });
    
    test('documents required capabilities for file uploads', () {
      // When creating a delegation for file uploads to Storacha, you need
      // these three capabilities to work together:
      
      const requiredCapabilities = [
        'space/blob/add',    // Uploads raw data blocks
        'space/index/add',   // Indexes the upload for retrieval
        'upload/add',        // Creates upload metadata linking blobs
      ];
      
      // Why all three?
      // 1. space/blob/add: Uploads the actual file data as content-addressed blocks
      // 2. upload/add: Creates a directory/file structure linking the blocks
      // 3. space/index/add: Registers the upload so it can be retrieved later
      
      // If you only need blob storage without retrieval metadata, you might
      // only need space/blob/add, but for typical file uploads you need all three.
      
      expect(requiredCapabilities.length, 3);
      expect(requiredCapabilities, contains('space/blob/add'));
      expect(requiredCapabilities, contains('space/index/add'));
      expect(requiredCapabilities, contains('upload/add'));
    });
    
    test('documents delegation format details', () {
      // The Storacha CLI outputs delegations in this format:
      //
      // 1. The delegation is a CAR (Content Addressable aRchive) file
      // 2. The CAR contains one or more UCAN tokens (as JWT strings)
      // 3. The CAR includes the full proof chain (parent UCANs)
      // 4. The entire CAR is base64-encoded
      // 5. A multibase prefix 'm' is added to indicate base64 encoding
      //
      // Example output format:
      // m<base64-encoded-car-data>
      //
      // The Delegation.fromFile() method handles all of this automatically:
      // - Detects and removes the 'm' prefix
      // - Decodes the base64 content
      // - Parses the CAR archive
      // - Extracts the root UCAN and proof chain
      // - Returns a Delegation object ready to use
      
      expect('Format documented', isNotEmpty);
    });
    
    test('explains common troubleshooting scenarios', () {
      // Common issues and solutions:
      //
      // 1. "Delegation audience mismatch"
      //    - Make sure the DID you passed to `storacha delegation create`
      //      matches your app's agent DID exactly
      //    - Save and reuse your agent key instead of generating a new one
      //
      // 2. "Delegation is expired"
      //    - Delegations have an expiration time set by the issuer
      //    - Create a new delegation with a longer validity period
      //
      // 3. "Missing capability"
      //    - Make sure you include all three capabilities:
      //      space/blob/add, space/index/add, upload/add
      //
      // 4. "Invalid delegation format"
      //    - Ensure you used the --base64 flag when creating the delegation
      //    - Check that the file wasn't corrupted during transfer
      //
      // 5. "Space DID not found"
      //    - The space DID is in the delegation's 'with' field
      //    - Extract it: delegation.capabilities.first.with_
      
      expect('Troubleshooting documented', isNotEmpty);
    });
  });
}
