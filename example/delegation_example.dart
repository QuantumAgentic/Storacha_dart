/// Example demonstrating UCAN delegation usage
///
/// This shows how to:
/// 1. Create a delegation (simulating Storacha CLI)
/// 2. Save it to a file
/// 3. Load it in your app
/// 4. Use it to upload files

import 'dart:io';
import 'package:storacha_dart/storacha_dart.dart';

Future<void> main() async {
  print('=== Storacha Delegation Example ===\n');

  // STEP 1: Simulate delegation creation (normally done by Storacha CLI)
  print('1. Creating a delegation...');

  // Space owner (the one who created the space via Storacha)
  final spaceOwner = await Ed25519Signer.generate();
  print('   Space owner DID: ${spaceOwner.did().did()}');

  // Your app's agent (the one that will upload files)
  final appAgent = await Ed25519Signer.generate();
  print('   App agent DID: ${appAgent.did().did()}');

  // Simulate space DID
  final spaceSigner = await Ed25519Signer.generate();
  final spaceDid = spaceSigner.did().did();
  print('   Space DID: $spaceDid');

  // Create delegation granting upload permissions
  final capabilities = [
    Capability(
      with_: spaceDid,
      can: 'space/blob/add',
      nb: {},
    ),
    Capability(
      with_: spaceDid,
      can: 'upload/add',
      nb: {},
    ),
  ];

  final ucan = await UCAN.create(
    issuer: spaceOwner,
    audience: appAgent.did().did(),
    capabilities: capabilities,
    lifetimeInSeconds: 86400, // 24 hours
  );

  final delegation = Delegation(ucan: ucan);
  print('   ✅ Delegation created with ${capabilities.length} capabilities\n');

  // STEP 2: Save delegation to file
  print('2. Saving delegation to file...');
  final delegationPath = 'example_delegation.ucan';
  await delegation.saveToFile(delegationPath);
  print('   ✅ Saved to: $delegationPath\n');

  // STEP 3: Load delegation from file (your app would do this)
  print('3. Loading delegation from file...');
  final loadedDelegation = await Delegation.fromFile(delegationPath);
  print('   ✅ Loaded delegation');
  print('   Issuer: ${loadedDelegation.issuer}');
  print('   Audience: ${loadedDelegation.audience}');
  print('   Valid until: ${DateTime.fromMillisecondsSinceEpoch(loadedDelegation.expiration! * 1000).toUtc()}\n');

  // STEP 4: Create client with delegation
  print('4. Creating Storacha client with delegation...');
  final config = ClientConfig(
    principal: appAgent,
    defaultProvider: 'did:web:up.storacha.network',
  );

  final client = StorachaClient(
    config,
    delegations: [loadedDelegation],
  );
  print('   ✅ Client created\n');

  // STEP 5: Add the delegated space
  print('5. Adding delegated space...');
  final delegatedSpace = Space(
    did: spaceDid,
    name: 'Delegated Space',
    signer: spaceSigner,
    createdAt: DateTime.now(),
  );

  client.addSpace(delegatedSpace);
  client.setCurrentSpace(spaceDid);
  print('   ✅ Space configured\n');

  // STEP 6: Verify delegation grants
  print('6. Verifying delegation capabilities...');
  final hasBlobAdd = loadedDelegation.grantsCapability('space/blob/add', resource: spaceDid);
  final hasUploadAdd = loadedDelegation.grantsCapability('upload/add', resource: spaceDid);
  print('   space/blob/add: ${hasBlobAdd ? "✅" : "❌"}');
  print('   upload/add: ${hasUploadAdd ? "✅" : "❌"}\n');

  // STEP 7: Check delegation in store
  print('7. Delegation store status...');
  print('   Total delegations: ${client.delegations.length}');
  print('   Valid delegations: ${client.delegations.valid.length}');

  final blobDelegations = client.delegations.findByCapability('space/blob/add');
  print('   Delegations with space/blob/add: ${blobDelegations.length}\n');

  // STEP 8: Demonstrate proof tokens
  print('8. Getting proof tokens for invocations...');
  final proofTokens = client.delegations.getProofTokens(
    forCapability: 'space/blob/add',
    forResource: spaceDid,
    forAudience: appAgent.did().did(),
  );
  print('   Found ${proofTokens.length} proof token(s)');
  if (proofTokens.isNotEmpty) {
    final token = proofTokens.first;
    final parts = token.split('.');
    print('   Token format: ${parts.length} parts (JWT)');
    print('   Token length: ${token.length} chars\n');
  }

  // Clean up
  client.close();
  final file = File(delegationPath);
  if (await file.exists()) {
    await file.delete();
  }

  print('✅ Example complete!\n');
  print('In production:');
  print('  1. Use Storacha CLI to create real delegations');
  print('  2. Load delegation.ucan file in your app');
  print('  3. Upload files with delegated permissions');
}

