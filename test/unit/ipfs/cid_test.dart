import 'dart:convert';
import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/multiformats/cid.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multibase.dart';
import 'package:storacha_dart/src/ipfs/multiformats/multihash.dart';
import 'package:test/test.dart';

void main() {
  group('CID creation', () {
    test('createV0 creates valid CIDv0', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final multihash = sha256Hash(data);

      final cid = CID.createV0(multihash);

      expect(cid.version, equals(CidVersion.v0));
      expect(cid.code, equals(dagPbCode));
      expect(cid.multihash, equals(multihash));
      expect(cid.bytes, equals(multihash.bytes));
    });

    test('createV1 creates valid CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final multihash = sha256Hash(data);

      final cid = CID.createV1(rawCode, multihash);

      expect(cid.version, equals(CidVersion.v1));
      expect(cid.code, equals(rawCode));
      expect(cid.multihash, equals(multihash));
      expect(cid.bytes.length, greaterThan(multihash.bytes.length));
    });

    test('create with CidVersion.v0', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);

      final cid = CID.create(
        version: CidVersion.v0,
        code: dagPbCode,
        multihash: multihash,
      );

      expect(cid.version, equals(CidVersion.v0));
      expect(cid.code, equals(dagPbCode));
    });

    test('create with CidVersion.v1', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);

      final cid = CID.create(
        version: CidVersion.v1,
        code: rawCode,
        multihash: multihash,
      );

      expect(cid.version, equals(CidVersion.v1));
      expect(cid.code, equals(rawCode));
    });

    test('throws on CIDv0 with non-dag-pb codec', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);

      expect(
        () => CID.create(
          version: CidVersion.v0,
          code: rawCode,
          multihash: multihash,
        ),
        throwsArgumentError,
      );
    });

    test('throws on CIDv0 with non-SHA-256', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha512Hash(data);

      expect(
        () => CID.createV0(multihash),
        throwsArgumentError,
      );
    });

    test('throws on empty digest', () {
      final emptyMultihash = createMultihash(0x12, Uint8List(0));

      expect(
        () => CID.createV1(rawCode, emptyMultihash),
        throwsArgumentError,
      );
    });
  });

  group('CID encoding/decoding', () {
    test('decode CIDv0 bytes', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final multihash = sha256Hash(data);
      final cid = CID.createV0(multihash);

      final decoded = CID.decode(cid.bytes);

      expect(decoded.version, equals(CidVersion.v0));
      expect(decoded.code, equals(dagPbCode));
      expect(decoded.multihash.bytes, equals(multihash.bytes));
    });

    test('decode CIDv1 bytes', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final decoded = CID.decode(cid.bytes);

      expect(decoded.version, equals(CidVersion.v1));
      expect(decoded.code, equals(rawCode));
      expect(decoded.multihash.bytes, equals(multihash.bytes));
    });

    test('decodeFirst returns CID and remainder', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final extraBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final combined = Uint8List.fromList([...cid.bytes, ...extraBytes]);

      final result = CID.decodeFirst(combined);
      final decodedCid = result.$1;
      final remainder = result.$2;

      expect(decodedCid, equals(cid));
      expect(remainder, equals(extraBytes));
    });

    test('decode throws on extra bytes', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final extraBytes = Uint8List.fromList([1, 2, 3]);
      final combined = Uint8List.fromList([...cid.bytes, ...extraBytes]);

      expect(
        () => CID.decode(combined),
        throwsArgumentError,
      );
    });

    test('round-trip encode/decode CIDv0', () {
      final data = Uint8List.fromList(utf8.encode('test data'));
      final multihash = sha256Hash(data);
      final original = CID.createV0(multihash);

      final decoded = CID.decode(original.bytes);

      expect(decoded, equals(original));
    });

    test('round-trip encode/decode CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('test data'));
      final multihash = sha256Hash(data);
      final original = CID.createV1(dagCborCode, multihash);

      final decoded = CID.decode(original.bytes);

      expect(decoded, equals(original));
    });
  });

  group('CID string parsing', () {
    test('parse CIDv0 string', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final multihash = sha256Hash(data);
      final cid = CID.createV0(multihash);

      final cidString = cid.toString();
      expect(cidString.startsWith('Q'), isTrue);

      final parsed = CID.parse(cidString);
      expect(parsed, equals(cid));
    });

    test('parse CIDv1 string (base32)', () {
      final data = Uint8List.fromList(utf8.encode('hello world'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final cidString = cid.toString();
      expect(cidString.startsWith('b'), isTrue); // base32 prefix

      final parsed = CID.parse(cidString);
      expect(parsed, equals(cid));
    });

    test('parse CIDv1 string (base58btc)', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final cidString = cid.toString(base58btc);
      expect(cidString.startsWith('z'), isTrue); // base58btc prefix

      final parsed = CID.parse(cidString);
      expect(parsed, equals(cid));
    });

    test('throws on empty string', () {
      expect(
        () => CID.parse(''),
        throwsArgumentError,
      );
    });

    test('throws on invalid CID string', () {
      expect(
        () => CID.parse('invalid-cid-string'),
        throwsA(anything),
      );
    });

    test('round-trip toString/parse CIDv0', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final original = CID.createV0(multihash);

      final cidString = original.toString();
      final parsed = CID.parse(cidString);

      expect(parsed, equals(original));
    });

    test('round-trip toString/parse CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final original = CID.createV1(rawCode, multihash);

      final cidString = original.toString();
      final parsed = CID.parse(cidString);

      expect(parsed, equals(original));
    });
  });

  group('CID version conversion', () {
    test('toV0 returns same for CIDv0', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV0(multihash);

      final v0 = cid.toV0();

      expect(identical(v0, cid), isTrue);
    });

    test('toV0 converts CIDv1 dag-pb to CIDv0', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cidV1 = CID.createV1(dagPbCode, multihash);

      final cidV0 = cidV1.toV0();

      expect(cidV0.version, equals(CidVersion.v0));
      expect(cidV0.code, equals(dagPbCode));
      expect(cidV0.multihash, equals(multihash));
    });

    test('toV0 throws on non-dag-pb CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      expect(cid.toV0, throwsStateError);
    });

    test('toV0 throws on non-SHA-256 CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha512Hash(data);
      final cid = CID.createV1(dagPbCode, multihash);

      expect(cid.toV0, throwsStateError);
    });

    test('toV1 returns same for CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final v1 = cid.toV1();

      expect(identical(v1, cid), isTrue);
    });

    test('toV1 converts CIDv0 to CIDv1', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cidV0 = CID.createV0(multihash);

      final cidV1 = cidV0.toV1();

      expect(cidV1.version, equals(CidVersion.v1));
      expect(cidV1.code, equals(dagPbCode));
      expect(cidV1.multihash, equals(multihash));
    });

    test('round-trip v0 -> v1 -> v0', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final original = CID.createV0(multihash);

      final v1 = original.toV1();
      final backToV0 = v1.toV0();

      expect(backToV0, equals(original));
    });
  });

  group('CID equality', () {
    test('equal CIDs are equal', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid1 = CID.createV1(rawCode, multihash);
      final cid2 = CID.createV1(rawCode, multihash);

      expect(cid1, equals(cid2));
      expect(cid1.hashCode, equals(cid2.hashCode));
    });

    test('different data produces different CIDs', () {
      final data1 = Uint8List.fromList(utf8.encode('test1'));
      final data2 = Uint8List.fromList(utf8.encode('test2'));
      final multihash1 = sha256Hash(data1);
      final multihash2 = sha256Hash(data2);

      final cid1 = CID.createV1(rawCode, multihash1);
      final cid2 = CID.createV1(rawCode, multihash2);

      expect(cid1, isNot(equals(cid2)));
    });

    test('different versions produce different CIDs', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cidV0 = CID.createV0(multihash);
      final cidV1 = CID.createV1(dagPbCode, multihash);

      expect(cidV0, isNot(equals(cidV1)));
    });

    test('different codecs produce different CIDs', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid1 = CID.createV1(rawCode, multihash);
      final cid2 = CID.createV1(dagCborCode, multihash);

      expect(cid1, isNot(equals(cid2)));
    });
  });

  group('CID JSON serialization', () {
    test('toJson produces correct format', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final cid = CID.createV1(rawCode, multihash);

      final json = cid.toJson();

      expect(json, contains('/'));
      expect(json['/'], isA<String>());
      expect(json['/'], equals(cid.toString()));
    });

    test('fromJson parses valid JSON', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final original = CID.createV1(rawCode, multihash);

      final json = original.toJson();
      final parsed = CID.fromJson(json);

      expect(parsed, equals(original));
    });

    test('fromJson throws on missing "/" field', () {
      expect(
        () => CID.fromJson({}),
        throwsArgumentError,
      );
    });

    test('fromJson throws on invalid "/" field', () {
      expect(
        () => CID.fromJson({'/': 123}),
        throwsArgumentError,
      );
    });

    test('round-trip toJson/fromJson', () {
      final data = Uint8List.fromList(utf8.encode('test'));
      final multihash = sha256Hash(data);
      final original = CID.createV1(rawCode, multihash);

      final json = original.toJson();
      final parsed = CID.fromJson(json);

      expect(parsed, equals(original));
    });
  });

  group('Integration tests', () {
    test('create CID for actual data', () {
      final content = utf8.encode('Hello, IPFS!');
      final data = Uint8List.fromList(content);

      // Hash the data
      final multihash = sha256Hash(data);

      // Create CID
      final cid = CID.createV1(rawCode, multihash);

      // Verify properties
      expect(cid.version, equals(CidVersion.v1));
      expect(cid.code, equals(rawCode));
      expect(cid.multihash.code, equals(0x12)); // SHA-256

      // Convert to string
      final cidString = cid.toString();
      expect(cidString, isNotEmpty);

      // Parse back
      final parsed = CID.parse(cidString);
      expect(parsed, equals(cid));
    });

    test('CIDv0 compatibility', () {
      final data = Uint8List.fromList(utf8.encode('legacy data'));
      final multihash = sha256Hash(data);

      // Create as v0
      final cidV0 = CID.createV0(multihash);
      expect(cidV0.version, equals(CidVersion.v0));

      // Convert to v1
      final cidV1 = cidV0.toV1();
      expect(cidV1.version, equals(CidVersion.v1));

      // Both should hash to same content
      expect(cidV1.multihash, equals(cidV0.multihash));
    });

    test('multiple codecs', () {
      final data = Uint8List.fromList(utf8.encode('data'));
      final multihash = sha256Hash(data);

      final raw = CID.createV1(rawCode, multihash);
      final dagPb = CID.createV1(dagPbCode, multihash);
      final dagCbor = CID.createV1(dagCborCode, multihash);

      expect(raw.code, equals(rawCode));
      expect(dagPb.code, equals(dagPbCode));
      expect(dagCbor.code, equals(dagCborCode));

      // All different even with same content
      expect(raw, isNot(equals(dagPb)));
      expect(dagPb, isNot(equals(dagCbor)));
    });
  });
}
