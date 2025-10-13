import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:storacha_dart/src/ipns/libp2p_key.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  group('Libp2pKey', () {
    test('generates valid CID v1 base36 from Ed25519 public key', () async {
      // Generate Ed25519 keypair
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final publicKeyBytes = Uint8List.fromList(publicKey.bytes);

      // Convert to CID
      final cid = Libp2pKey.publicKeyToCid(publicKeyBytes);

      // Verify format
      expect(cid, startsWith('k')); // base36 prefix
      expect(cid.length, greaterThan(50)); // Reasonable length
      expect(Libp2pKey.isValidCid(cid), isTrue);

      print('✅ Generated CID: $cid');
    });

    test('roundtrip: public key → CID → public key', () async {
      // Generate keypair
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final originalBytes = Uint8List.fromList(publicKey.bytes);

      // Convert to CID
      final cid = Libp2pKey.publicKeyToCid(originalBytes);

      // Extract public key back
      final extractedBytes = Libp2pKey.publicKeyFromCid(cid);

      // Should match
      expect(extractedBytes, equals(originalBytes));

      print('✅ Roundtrip successful: ${originalBytes.length} bytes');
    });

    test('matches known w3name format', () {
      // Example CID from w3name test
      const knownCid =
          'k51qzi5uqu5dhln19ue28sk48c00i8nkgei5esr6s78jwinec5ghnrgcabugeu';

      // Should be valid
      expect(Libp2pKey.isValidCid(knownCid), isTrue);

      // Should extract without error
      expect(
        () => Libp2pKey.publicKeyFromCid(knownCid),
        returnsNormally,
      );

      print('✅ Known w3name CID validated');
    });

    test('rejects invalid CID', () {
      expect(Libp2pKey.isValidCid('invalid'), isFalse);
      expect(Libp2pKey.isValidCid(''), isFalse);
      expect(Libp2pKey.isValidCid('k'), isFalse);
    });

    test('rejects non-Ed25519 key length', () {
      final invalidKey = Uint8List(16); // Too short

      expect(
        () => Libp2pKey.publicKeyToCid(invalidKey),
        throwsArgumentError,
      );
    });

    test('two different keys produce different CIDs', () async {
      final algorithm = Ed25519();

      // Generate two different keypairs
      final keyPair1 = await algorithm.newKeyPair();
      final publicKey1 = await keyPair1.extractPublicKey();
      final bytes1 = Uint8List.fromList(publicKey1.bytes);

      final keyPair2 = await algorithm.newKeyPair();
      final publicKey2 = await keyPair2.extractPublicKey();
      final bytes2 = Uint8List.fromList(publicKey2.bytes);

      // Convert to CIDs
      final cid1 = Libp2pKey.publicKeyToCid(bytes1);
      final cid2 = Libp2pKey.publicKeyToCid(bytes2);

      // Should be different
      expect(cid1, isNot(equals(cid2)));

      print('✅ CID uniqueness verified');
    });
  });
}

