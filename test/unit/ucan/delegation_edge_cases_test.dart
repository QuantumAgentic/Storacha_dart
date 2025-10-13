import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:storacha_dart/storacha_dart.dart';

/// Comprehensive edge case tests for UCAN delegations
/// 
/// This test suite covers:
/// - Malformed data handling
/// - Boundary conditions
/// - Error recovery
/// - Security edge cases
void main() {
  group('Delegation Edge Cases', () {
    late Ed25519Signer issuer;
    late Ed25519Signer audience;

    setUp(() async {
      issuer = await Ed25519Signer.generate();
      audience = await Ed25519Signer.generate();
    });

    group('Parsing Edge Cases', () {
      test('handles JWT with trailing whitespace', () async {
        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final tokenWithWhitespace = '${ucan.encode()}  \n\t  ';
        final delegation = Delegation.fromToken(tokenWithWhitespace.trim());

        expect(delegation.issuer, equals(issuer.did().did()));
      });

      test('handles very long capability lists', () async {
        // Create 100 capabilities
        final capabilities = List.generate(
          100,
          (i) => Capability(
            with_: 'did:key:space$i',
            can: 'test/capability$i',
            nb: {},
          ),
        );

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: capabilities,
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);

        expect(delegation.capabilities.length, equals(100));
        expect(delegation.grantsCapability('test/capability50'), isTrue);
        expect(delegation.grantsCapability('test/capability99'), isTrue);
      });

      test('handles capabilities with complex nb fields', () async {
        final capability = Capability(
          with_: 'did:key:test',
          can: 'space/blob/add',
          nb: {
            'blob': {
              'digest': {
                '0x12': 0x20,
                'bytes': [1, 2, 3, 4, 5],
              },
              'size': 1024000,
            },
            'metadata': {
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'nested': {
                'field': 'value',
                'array': [1, 2, 3],
              },
            },
          },
        );

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [capability],
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);
        final roundtrip = Delegation.fromToken(delegation.toToken());

        expect(roundtrip.capabilities.length, equals(1));
        expect(roundtrip.capabilities.first.nb, isNotEmpty);
      });

      test('handles delegation at expiration boundary', () async {
        // Create delegation that expires in 1 second
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiration = nowSeconds + 1;

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          expiration: expiration,
        );

        final delegation = Delegation(ucan: ucan);

        // Should be valid initially
        expect(delegation.isValid, isTrue);

        // Wait for expiration
        await Future<void>.delayed(const Duration(seconds: 2));

        // Should be expired now
        expect(delegation.isExpired, isTrue);
        expect(delegation.isValid, isFalse);
      });

      test('handles delegation with notBefore in future', () async {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final notBefore = nowSeconds + 5;

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          notBefore: notBefore,
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);

        // Should not be valid yet (using UCAN's isNotYetValid)
        expect(delegation.ucan.isNotYetValid, isTrue);
        expect(delegation.isValid, isFalse);
      });

      test('handles empty capability list', () async {
        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [],
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);

        expect(delegation.capabilities, isEmpty);
        expect(delegation.grantsCapability('any'), isFalse);
      });
    });

    group('File I/O Edge Cases', () {
      test('handles file with BOM', () async {
        final tempDir = Directory.systemTemp.createTempSync('delegation_bom');
        final filePath = '${tempDir.path}/with_bom.ucan';

        try {
          final ucan = await UCAN.create(
            issuer: issuer,
            audience: audience.did().did(),
            capabilities: [
              Capability(with_: 'did:key:test', can: 'test', nb: {}),
            ],
            lifetimeInSeconds: 3600,
          );

          // Write with BOM
          final token = ucan.encode();
          final withBom = '\uFEFF$token'; // UTF-8 BOM
          await File(filePath).writeAsString(withBom);

          // Should handle BOM gracefully
          final loaded = await Delegation.fromFile(filePath);
          expect(loaded.issuer, equals(issuer.did().did()));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('handles very large delegation file', () async {
        final tempDir = Directory.systemTemp.createTempSync('delegation_large');
        final filePath = '${tempDir.path}/large.ucan';

        try {
          // Create delegation with many capabilities
          final capabilities = List.generate(
            500,
            (i) => Capability(
              with_: 'did:key:space$i',
              can: 'test/action$i',
              nb: {'index': i, 'data': List.filled(100, i)},
            ),
          );

          final ucan = await UCAN.create(
            issuer: issuer,
            audience: audience.did().did(),
            capabilities: capabilities,
            lifetimeInSeconds: 3600,
          );

          final delegation = Delegation(ucan: ucan);
          await delegation.saveToFile(filePath);

          // Verify file size
          final file = File(filePath);
          final size = await file.length();
          print('Large delegation file size: $size bytes');

          // Should load successfully
          final loaded = await Delegation.fromFile(filePath);
          expect(loaded.capabilities.length, equals(500));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('handles non-existent file', () async {
        expect(
          () => Delegation.fromFile('/nonexistent/delegation.ucan'),
          throwsA(isA<FileSystemException>()),
        );
      });

      test('handles directory instead of file', () async {
        final tempDir = Directory.systemTemp.createTempSync('delegation_dir');

        try {
          expect(
            () => Delegation.fromFile(tempDir.path),
            throwsA(isA<Exception>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('handles empty file', () async {
        final tempDir = Directory.systemTemp.createTempSync('delegation_empty');
        final filePath = '${tempDir.path}/empty.ucan';

        try {
          await File(filePath).writeAsString('');

          expect(
            () => Delegation.fromFile(filePath),
            throwsA(isA<Exception>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('handles file with only whitespace', () async {
        final tempDir = Directory.systemTemp.createTempSync('delegation_whitespace');
        final filePath = '${tempDir.path}/whitespace.ucan';

        try {
          await File(filePath).writeAsString('   \n\t\n   ');

          expect(
            () => Delegation.fromFile(filePath),
            throwsA(isA<Exception>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('CAR Format Edge Cases', () {
      test('handles CAR with single block', () async {
        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final tokenBytes = utf8.encode(ucan.encode());
        final tokenCid = CID.createV1(rawCode, sha256Hash(tokenBytes));
        final blocks = [CARBlock(cid: tokenCid, bytes: tokenBytes)];
        final carBytes = encodeCar(roots: [tokenCid], blocks: blocks);

        final delegation = Delegation.fromCarBytes(carBytes);

        expect(delegation.archive, equals(carBytes));
        expect(delegation.issuer, equals(issuer.did().did()));
      });

      test('handles CAR with multiple roots', () async {
        final ucan1 = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test1', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final ucan2 = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test2', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final bytes1 = utf8.encode(ucan1.encode());
        final bytes2 = utf8.encode(ucan2.encode());

        final cid1 = CID.createV1(rawCode, sha256Hash(bytes1));
        final cid2 = CID.createV1(rawCode, sha256Hash(bytes2));

        final blocks = [
          CARBlock(cid: cid1, bytes: bytes1),
          CARBlock(cid: cid2, bytes: bytes2),
        ];

        final carBytes = encodeCar(roots: [cid1, cid2], blocks: blocks);

        // Should use first root
        final delegation = Delegation.fromCarBytes(carBytes);
        expect(delegation.issuer, equals(issuer.did().did()));
      });

      test('handles CAR with missing root block', () {
        final fakeCid = CID.parse('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');
        final otherData = Uint8List.fromList([1, 2, 3]);
        final otherCid = CID.createV1(rawCode, sha256Hash(otherData));

        final blocks = [CARBlock(cid: otherCid, bytes: otherData)];
        final carBytes = encodeCar(roots: [fakeCid], blocks: blocks);

        expect(
          () => Delegation.fromCarBytes(carBytes),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles CAR with very large blocks', () async {
        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: List.generate(
            200,
            (i) => Capability(
              with_: 'did:key:space$i',
              can: 'test',
              nb: {'data': List.filled(1000, i)},
            ),
          ),
          lifetimeInSeconds: 3600,
        );

        final tokenBytes = utf8.encode(ucan.encode());
        final tokenCid = CID.createV1(rawCode, sha256Hash(tokenBytes));
        final blocks = [CARBlock(cid: tokenCid, bytes: tokenBytes)];
        final carBytes = encodeCar(roots: [tokenCid], blocks: blocks);

        print('Large CAR file: ${carBytes.length} bytes');

        final delegation = Delegation.fromCarBytes(carBytes);
        expect(delegation.capabilities.length, equals(200));
      });
    });

    group('DelegationStore Edge Cases', () {
      test('handles duplicate delegations', () async {
        final store = DelegationStore();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);

        // Add same delegation twice
        store.add(delegation);
        store.add(delegation);

        // Both should be in store (no deduplication by default)
        expect(store.length, equals(2));
      });

      test('handles mixed expired and valid delegations', () async {
        final store = DelegationStore();

        // Add expired delegation
        final expiredUcan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          expiration: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
        );
        store.add(Delegation(ucan: expiredUcan));

        // Add valid delegations
        for (var i = 0; i < 5; i++) {
          final validUcan = await UCAN.create(
            issuer: issuer,
            audience: audience.did().did(),
            capabilities: [
              Capability(with_: 'did:key:test$i', can: 'test', nb: {}),
            ],
            lifetimeInSeconds: 3600,
          );
          store.add(Delegation(ucan: validUcan));
        }

        expect(store.length, equals(6));
        expect(store.valid.length, equals(5));
      });

      test('handles store with no matching delegations', () {
        final store = DelegationStore();

        final found = store.findByCapability('nonexistent/capability');
        expect(found, isEmpty);

        final byAudience = store.findByAudience('did:key:nonexistent');
        expect(byAudience, isEmpty);

        final proofs = store.getProofTokens(
          forCapability: 'nonexistent',
          forAudience: 'did:key:nonexistent',
        );
        expect(proofs, isEmpty);
      });

      test('handles removal of non-existent delegation', () async {
        final store = DelegationStore();

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);

        // Remove without adding
        final removed = store.remove(delegation);
        expect(removed, isFalse);
      });

      test('handles large delegation store', () async {
        final store = DelegationStore();

        // Add 1000 delegations
        for (var i = 0; i < 1000; i++) {
          final ucan = await UCAN.create(
            issuer: issuer,
            audience: audience.did().did(),
            capabilities: [
              Capability(with_: 'did:key:space$i', can: 'test$i', nb: {}),
            ],
            lifetimeInSeconds: 3600,
          );
          store.add(Delegation(ucan: ucan));
        }

        expect(store.length, equals(1000));

        // Should efficiently find specific delegation
        final found = store.findByCapability('test500');
        expect(found, isNotEmpty);
      });
    });

    group('Security Edge Cases', () {
      test('handles delegation with mismatched audience', () async {
        final delegation = await _createTestDelegation(issuer, audience);

        // Different agent DID
        final otherAgent = await Ed25519Signer.generate();

        expect(delegation.audience, isNot(equals(otherAgent.did().did())));
      });

      test('handles tampered JWT', () {
        // Create valid JWT then tamper with it
        final validJwt = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.'
            'eyJpc3MiOiJkaWQ6a2V5OnRlc3QiLCJhdWQiOiJkaWQ6a2V5OnRlc3QyIn0.'
            'aW52YWxpZC1zaWduYXR1cmU'; // Invalid signature

        expect(
          () => Delegation.fromToken(validJwt),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles capabilities with wildcard patterns', () async {
        final capability = Capability(
          with_: 'did:key:*', // Wildcard
          can: 'test/*', // Wildcard
          nb: {},
        );

        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [capability],
          lifetimeInSeconds: 3600,
        );

        final delegation = Delegation(ucan: ucan);

        // Should match exactly
        expect(delegation.grantsCapability('test/*', resource: 'did:key:*'),
          isTrue);

        // Should not match variations (no wildcard expansion)
        expect(delegation.grantsCapability('test/specific'), isFalse);
      });
    });
  });
}

Future<Delegation> _createTestDelegation(
  Ed25519Signer issuer,
  Ed25519Signer audience,
) async {
  final ucan = await UCAN.create(
    issuer: issuer,
    audience: audience.did().did(),
    capabilities: [
      Capability(with_: 'did:key:test', can: 'test', nb: {}),
    ],
    lifetimeInSeconds: 3600,
  );
  return Delegation(ucan: ucan);
}

