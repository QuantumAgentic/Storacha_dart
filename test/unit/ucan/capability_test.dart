import 'package:storacha_dart/src/ucan/capability.dart';
import 'package:test/test.dart';

void main() {
  group('Capability', () {
    group('constructor', () {
      test('creates capability with required fields', () {
        const capability = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
        );

        expect(capability.with_, 'did:key:z6Mkf...');
        expect(capability.can, 'store/add');
        expect(capability.nb, isNull);
      });

      test('creates capability with caveats', () {
        const capability = Capability(
          with_: 'ipfs://bafybei...',
          can: 'store/remove',
          nb: {'size': 1000000},
        );

        expect(capability.nb, isNotNull);
        expect(capability.nb!['size'], 1000000);
      });
    });

    group('fromJson', () {
      test('parses capability from JSON', () {
        final json = {
          'with': 'did:key:z6Mkf...',
          'can': 'store/add',
        };

        final capability = Capability.fromJson(json);

        expect(capability.with_, 'did:key:z6Mkf...');
        expect(capability.can, 'store/add');
        expect(capability.nb, isNull);
      });

      test('parses capability with caveats from JSON', () {
        final json = {
          'with': 'ipfs://bafybei...',
          'can': 'upload/*',
          'nb': {'link': 'bafybei...', 'size': 5000},
        };

        final capability = Capability.fromJson(json);

        expect(capability.with_, 'ipfs://bafybei...');
        expect(capability.can, 'upload/*');
        expect(capability.nb!['link'], 'bafybei...');
        expect(capability.nb!['size'], 5000);
      });
    });

    group('toJson', () {
      test('converts capability to JSON', () {
        const capability = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
        );

        final json = capability.toJson();

        expect(json['with'], 'did:key:z6Mkf...');
        expect(json['can'], 'store/add');
        expect(json.containsKey('nb'), isFalse);
      });

      test('converts capability with caveats to JSON', () {
        const capability = Capability(
          with_: 'ipfs://bafybei...',
          can: 'upload/*',
          nb: {'link': 'bafybei...'},
        );

        final json = capability.toJson();

        expect(json['with'], 'ipfs://bafybei...');
        expect(json['can'], 'upload/*');
        expect(json['nb'], isNotNull);
        final nb = json['nb'] as Map<String, dynamic>;
        expect(nb['link'], 'bafybei...');
      });

      test('omits empty caveats from JSON', () {
        const capability = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
          nb: {},
        );

        final json = capability.toJson();

        expect(json.containsKey('nb'), isFalse);
      });
    });

    group('equality', () {
      test('equal capabilities are equal', () {
        const cap1 = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
        );
        const cap2 = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
        );

        expect(cap1, equals(cap2));
        expect(cap1.hashCode, equals(cap2.hashCode));
      });

      test('capabilities with different resources are not equal', () {
        const cap1 = Capability(
          with_: 'did:key:z6Mkf1...',
          can: 'store/add',
        );
        const cap2 = Capability(
          with_: 'did:key:z6Mkf2...',
          can: 'store/add',
        );

        expect(cap1, isNot(equals(cap2)));
      });

      test('capabilities with different abilities are not equal', () {
        const cap1 = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
        );
        const cap2 = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/remove',
        );

        expect(cap1, isNot(equals(cap2)));
      });

      test('capabilities with different caveats are not equal', () {
        const cap1 = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
          nb: {'size': 1000},
        );
        const cap2 = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
          nb: {'size': 2000},
        );

        expect(cap1, isNot(equals(cap2)));
      });
    });

    group('toString', () {
      test('formats capability without caveats', () {
        const capability = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
        );

        final str = capability.toString();

        expect(str, contains('did:key:z6Mkf...'));
        expect(str, contains('store/add'));
      });

      test('formats capability with caveats', () {
        const capability = Capability(
          with_: 'ipfs://bafybei...',
          can: 'upload/*',
          nb: {'size': 1000},
        );

        final str = capability.toString();

        expect(str, contains('ipfs://bafybei...'));
        expect(str, contains('upload/*'));
        expect(str, contains('nb:'));
      });
    });

    group('integration', () {
      test('round-trip: capability -> JSON -> capability', () {
        const original = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/add',
          nb: {'size': 5000, 'link': 'bafybei...'},
        );

        final json = original.toJson();
        final parsed = Capability.fromJson(json);

        expect(parsed, equals(original));
      });

      test('wildcards are supported', () {
        const capability = Capability(
          with_: 'did:key:z6Mkf...',
          can: '*',
        );

        expect(capability.can, '*');
      });

      test('nested abilities are supported', () {
        const capability = Capability(
          with_: 'did:key:z6Mkf...',
          can: 'store/upload/batch',
        );

        expect(capability.can, 'store/upload/batch');
      });
    });
  });
}
