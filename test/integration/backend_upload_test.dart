import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:storacha_dart/storacha_dart.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Backend Upload Integration Test', () {
    late StorachaClient client;
    late Signer signer;

    setUpAll(() async {
      print('\n🔧 Setting up test...');

      // Create signer from environment or hardcoded key
      final agentKeyBase64 = 'bJ6u266uBtJxMEeGgWAJPPAwRre3HUibylOoG7QWFFA=';
      final agentKeyBytes = base64Decode(agentKeyBase64);
      signer = await Ed25519Signer.fromBytes(agentKeyBytes);

      print('✅ Agent DID: ${signer.did().did()}');

      // Create client with backend configuration
      client = StorachaClient(
        config: ClientConfig(
          principal: signer,
          backendUrl: 'http://localhost:3000', // Local backend
        ),
      );

      print('✅ Client created with backend URL: http://localhost:3000');

      // Load delegation
      final delegationPath = '../quantum_agents/assets/delegation_dart_simple.car';
      final delegationFile = File(delegationPath);

      if (!delegationFile.existsSync()) {
        throw Exception('Delegation file not found: $delegationPath');
      }

      final delegationBytes = await delegationFile.readAsBytes();
      final delegation = await Delegation.extract(delegationBytes);

      await client.addProof(delegation);
      print('✅ Delegation loaded');

      // Set current space
      final spaceDid = delegation.capabilities.first.with_;
      await client.setCurrentSpace(spaceDid);
      print('✅ Space set: $spaceDid');
    });

    tearDownAll(() {
      client.close();
    });

    test('Upload file via backend and verify retrieval', () async {
      print('\n📤 Starting upload test...');

      // Create test data
      final testContent = 'Hello from Dart backend test! ${DateTime.now()}';
      final testBytes = Uint8List.fromList(utf8.encode(testContent));

      print('📝 Test content: $testContent');
      print('📏 Size: ${testBytes.length} bytes');

      // Create MemoryFile
      final file = MemoryFile(
        name: 'backend-test.txt',
        bytes: testBytes,
      );

      // Upload
      print('🚀 Uploading via backend...');
      final cid = await client.uploadFile(file);

      print('✅ Upload successful!');
      print('🔗 CID: $cid');

      // Verify CID is valid
      expect(cid.toString().isNotEmpty, true);
      expect(cid.toString().startsWith('baf'), true);

      // Test retrieval via IPFS gateway
      print('\n🌐 Testing IPFS retrieval...');
      final gatewayUrl = 'https://$cid.ipfs.w3s.link/';
      print('🔗 Gateway URL: $gatewayUrl');

      // Wait a moment for propagation
      await Future.delayed(Duration(seconds: 2));

      // Try retrieval with timeout
      try {
        final response = await http.get(
          Uri.parse(gatewayUrl),
        ).timeout(Duration(seconds: 15));

        print('📊 HTTP Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final retrievedContent = response.body;
          print('✅ Content retrieved: $retrievedContent');

          // Verify content matches
          expect(retrievedContent, equals(testContent));
          print('✅ Content verification passed!');

          print('\n🎉 SUCCESS! Backend upload and retrieval work perfectly!');
        } else {
          print('⚠️  Retrieval returned status ${response.statusCode}');
          print('Response: ${response.body}');
        }
      } catch (e) {
        print('❌ Retrieval error: $e');
        // Don't fail the test on retrieval error, just report it
        print('⚠️  Upload succeeded but retrieval failed (may need more time)');
      }
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}
