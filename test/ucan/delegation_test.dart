import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:storacha_dart/storacha_dart.dart';

void main() {
  group('Delegation', () {
    late Ed25519Signer issuer;
    late Ed25519Signer audience;

    setUp(() async {
      issuer = await Ed25519Signer.generate();
      audience = await Ed25519Signer.generate();
    });

    test('create from UCAN token', () async {
      // Create a UCAN token
      final capability = Capability(
        with_: 'did:key:z6MkTestSpace123',
        can: 'space/blob/add',
        nb: {},
      );

      final ucan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [capability],
        lifetimeInSeconds: 3600,
      );

      // Create delegation from token
      final delegation = Delegation.fromToken(ucan.encode());

      expect(delegation.issuer, equals(issuer.did().did()));
      expect(delegation.audience, equals(audience.did().did()));
      expect(delegation.capabilities.length, equals(1));
      expect(delegation.capabilities.first.can, equals('space/blob/add'));
      expect(delegation.isValid, isTrue);
    });

    test('parse JWT string', () async {
      final capability = Capability(
        with_: 'did:key:z6MkTestSpace456',
        can: 'upload/add',
        nb: {'root': 'bafyTest123'},
      );

      final ucan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [capability],
        lifetimeInSeconds: 7200,
      );

      final token = ucan.encode();
      final delegation = Delegation.fromToken(token);

      // Verify roundtrip
      expect(delegation.toToken(), equals(token));
    });

    test('check capability grants', () async {
      final blobCap = Capability(
        with_: 'did:key:z6MkSpace1',
        can: 'space/blob/add',
        nb: {},
      );

      final uploadCap = Capability(
        with_: 'did:key:z6MkSpace1',
        can: 'upload/add',
        nb: {},
      );

      final ucan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [blobCap, uploadCap],
        lifetimeInSeconds: 3600,
      );

      final delegation = Delegation(ucan: ucan);

      expect(delegation.grantsCapability('space/blob/add'), isTrue);
      expect(delegation.grantsCapability('upload/add'), isTrue);
      expect(delegation.grantsCapability('space/info'), isFalse);

      expect(
        delegation.grantsCapability('space/blob/add',
            resource: 'did:key:z6MkSpace1'),
        isTrue,
      );
      expect(
        delegation.grantsCapability('space/blob/add',
            resource: 'did:key:z6MkSpace2'),
        isFalse,
      );
    });

    test('expiration check', () async {
      // Create expired delegation
      final expiredUcan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [
          Capability(with_: 'did:key:test', can: 'test', nb: {}),
        ],
        expiration: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
      );

      final expiredDelegation = Delegation(ucan: expiredUcan);
      expect(expiredDelegation.isExpired, isTrue);
      expect(expiredDelegation.isValid, isFalse);

      // Create valid delegation
      final validUcan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [
          Capability(with_: 'did:key:test', can: 'test', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      final validDelegation = Delegation(ucan: validUcan);
      expect(validDelegation.isExpired, isFalse);
      expect(validDelegation.isValid, isTrue);
    });

    test('save and load from file', () async {
      final tempDir = Directory.systemTemp.createTempSync('delegation_test');
      final filePath = '${tempDir.path}/test.ucan';

      try {
        // Create delegation
        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'test', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final original = Delegation(ucan: ucan);

        // Save to file
        await original.saveToFile(filePath);

        // Load from file
        final loaded = await Delegation.fromFile(filePath);

        // Verify
        expect(loaded.toToken(), equals(original.toToken()));
        expect(loaded.issuer, equals(original.issuer));
        expect(loaded.audience, equals(original.audience));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('parse from CAR format', () async {
      // Create UCAN token
      final ucan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [
          Capability(with_: 'did:key:test', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      final jwtToken = ucan.encode();
      final tokenBytes = utf8.encode(jwtToken);

      // Create CAR file with UCAN as a block
      final tokenCid = CID.createV1(rawCode, sha256Hash(tokenBytes));
      final blocks = [
        CARBlock(cid: tokenCid, bytes: tokenBytes),
      ];
      final carBytes = encodeCar(roots: [tokenCid], blocks: blocks);

      // Parse delegation from CAR
      final delegation = Delegation.fromCarBytes(carBytes);

      // Verify
      expect(delegation.issuer, equals(issuer.did().did()));
      expect(delegation.audience, equals(audience.did().did()));
      expect(delegation.capabilities.length, equals(1));
      expect(delegation.capabilities.first.can, equals('space/blob/add'));
      expect(delegation.archive, isNotNull);
      expect(delegation.archive, equals(carBytes));
    });

    test('parse CAR with multiple UCAN blocks', () async {
      // Create root UCAN
      final rootUcan = await UCAN.create(
        issuer: issuer,
        audience: audience.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      // Create additional UCAN (simulating proof chain)
      final proofUcan = await UCAN.create(
        issuer: issuer,
        audience: 'did:key:intermediate',
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 7200,
      );

      final rootTokenBytes = utf8.encode(rootUcan.encode());
      final proofTokenBytes = utf8.encode(proofUcan.encode());

      final rootCid = CID.createV1(rawCode, sha256Hash(rootTokenBytes));
      final proofCid = CID.createV1(rawCode, sha256Hash(proofTokenBytes));

      final blocks = [
        CARBlock(cid: rootCid, bytes: rootTokenBytes),
        CARBlock(cid: proofCid, bytes: proofTokenBytes),
      ];

      final carBytes = encodeCar(roots: [rootCid], blocks: blocks);

      // Parse delegation from CAR
      final delegation = Delegation.fromCarBytes(carBytes);

      // Should parse the root UCAN
      expect(delegation.issuer, equals(issuer.did().did()));
      expect(delegation.audience, equals(audience.did().did()));
      expect(delegation.archive, equals(carBytes));
    });

    test('load CAR file from disk', () async {
      final tempDir = Directory.systemTemp.createTempSync('delegation_car_test');
      final filePath = '${tempDir.path}/test.car';

      try {
        // Create UCAN and CAR file
        final ucan = await UCAN.create(
          issuer: issuer,
          audience: audience.did().did(),
          capabilities: [
            Capability(with_: 'did:key:test', can: 'upload/add', nb: {}),
          ],
          lifetimeInSeconds: 3600,
        );

        final tokenBytes = utf8.encode(ucan.encode());
        final tokenCid = CID.createV1(rawCode, sha256Hash(tokenBytes));
        final blocks = [CARBlock(cid: tokenCid, bytes: tokenBytes)];
        final carBytes = encodeCar(roots: [tokenCid], blocks: blocks);

        // Save CAR file
        await File(filePath).writeAsBytes(carBytes);

        // Load delegation from CAR file
        final delegation = await Delegation.fromFile(filePath);

        // Verify
        expect(delegation.issuer, equals(issuer.did().did()));
        expect(delegation.audience, equals(audience.did().did()));
        expect(delegation.capabilities.first.can, equals('upload/add'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('invalid CAR throws FormatException', () {
      final invalidBytes = Uint8List.fromList([0xFF, 0xFF, 0xFF]);

      expect(
        () => Delegation.fromCarBytes(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty CAR throws FormatException', () {
      final carBytes = encodeCar(roots: [], blocks: []);

      expect(
        () => Delegation.fromCarBytes(carBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('CAR with non-UCAN data throws FormatException', () async {
      // Create CAR with random data (not a UCAN)
      final randomData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final cid = CID.createV1(rawCode, sha256Hash(randomData));
      final blocks = [CARBlock(cid: cid, bytes: randomData)];
      final carBytes = encodeCar(roots: [cid], blocks: blocks);

      expect(
        () => Delegation.fromCarBytes(carBytes),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DelegationStore', () {
    late Ed25519Signer issuer;
    late Ed25519Signer audience1;
    late Ed25519Signer audience2;

    setUp(() async {
      issuer = await Ed25519Signer.generate();
      audience1 = await Ed25519Signer.generate();
      audience2 = await Ed25519Signer.generate();
    });

    test('add and retrieve delegations', () async {
      final store = DelegationStore();

      final ucan1 = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      final ucan2 = await UCAN.create(
        issuer: issuer,
        audience: audience2.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'upload/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      store.add(Delegation(ucan: ucan1));
      store.add(Delegation(ucan: ucan2));

      expect(store.length, equals(2));
      expect(store.isEmpty, isFalse);
      expect(store.isNotEmpty, isTrue);
    });

    test('find by capability', () async {
      final store = DelegationStore();

      final blobUcan = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      final uploadUcan = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'upload/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      store.add(Delegation(ucan: blobUcan));
      store.add(Delegation(ucan: uploadUcan));

      final blobDelegations = store.findByCapability('space/blob/add');
      expect(blobDelegations.length, equals(1));
      expect(blobDelegations.first.capabilities.first.can,
          equals('space/blob/add'));

      final uploadDelegations = store.findByCapability('upload/add');
      expect(uploadDelegations.length, equals(1));
      expect(uploadDelegations.first.capabilities.first.can,
          equals('upload/add'));
    });

    test('find by audience', () async {
      final store = DelegationStore();

      final ucan1 = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      final ucan2 = await UCAN.create(
        issuer: issuer,
        audience: audience2.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'upload/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      store.add(Delegation(ucan: ucan1));
      store.add(Delegation(ucan: ucan2));

      final aud1Delegations = store.findByAudience(audience1.did().did());
      expect(aud1Delegations.length, equals(1));
      expect(aud1Delegations.first.audience, equals(audience1.did().did()));

      final aud2Delegations = store.findByAudience(audience2.did().did());
      expect(aud2Delegations.length, equals(1));
      expect(aud2Delegations.first.audience, equals(audience2.did().did()));
    });

    test('get proof tokens', () async {
      final store = DelegationStore();

      final ucan = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      store.add(Delegation(ucan: ucan));

      final proofs = store.getProofTokens(
        forCapability: 'space/blob/add',
        forAudience: audience1.did().did(),
      );

      expect(proofs.length, equals(1));
      expect(proofs.first, isA<String>());
      expect(proofs.first.split('.').length, equals(3)); // JWT format
    });

    test('filter out expired delegations', () async {
      final store = DelegationStore();

      // Add expired delegation
      final expiredUcan = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        expiration: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
      );

      // Add valid delegation
      final validUcan = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'upload/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      store.add(Delegation(ucan: expiredUcan));
      store.add(Delegation(ucan: validUcan));

      expect(store.length, equals(2));
      expect(store.valid.length, equals(1));
      expect(store.valid.first.capabilities.first.can, equals('upload/add'));
    });

    test('clear store', () async {
      final store = DelegationStore();

      final ucan = await UCAN.create(
        issuer: issuer,
        audience: audience1.did().did(),
        capabilities: [
          Capability(with_: 'did:key:space1', can: 'space/blob/add', nb: {}),
        ],
        lifetimeInSeconds: 3600,
      );

      store.add(Delegation(ucan: ucan));
      expect(store.length, equals(1));

      store.clear();
      expect(store.isEmpty, isTrue);
      expect(store.length, equals(0));
    });
  });
}

