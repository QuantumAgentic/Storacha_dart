import 'dart:typed_data';

import 'package:storacha_dart/src/ipfs/unixfs/protobuf_encoder.dart';
import 'package:test/test.dart';

void main() {
  group('ProtobufEncoder', () {
    test('encodes uint32 field', () {
      final encoder = ProtobufEncoder();
      encoder.writeUint32(1, 42);
      final bytes = encoder.toBytes();

      // Field 1, wire type 0 (varint): tag = (1 << 3) | 0 = 0x08
      // Value 42 = 0x2a
      expect(bytes, equals([0x08, 0x2a]));
    });

    test('encodes uint64 field', () {
      final encoder = ProtobufEncoder();
      encoder.writeUint64(3, 1024);
      final bytes = encoder.toBytes();

      // Field 3, wire type 0: tag = (3 << 3) | 0 = 0x18
      // Value 1024 = 0x800 = varint [0x80, 0x08]
      expect(bytes, equals([0x18, 0x80, 0x08]));
    });

    test('encodes bytes field', () {
      final encoder = ProtobufEncoder();
      encoder.writeBytes(2, Uint8List.fromList([0x01, 0x02, 0x03]));
      final bytes = encoder.toBytes();

      // Field 2, wire type 2: tag = (2 << 3) | 2 = 0x12
      // Length 3 = 0x03
      // Data [0x01, 0x02, 0x03]
      expect(bytes, equals([0x12, 0x03, 0x01, 0x02, 0x03]));
    });

    test('encodes string field', () {
      final encoder = ProtobufEncoder();
      encoder.writeString(2, 'test');
      final bytes = encoder.toBytes();

      // Field 2, wire type 2: tag = 0x12
      // Length 4
      // UTF-8: 't' 'e' 's' 't'
      expect(
        bytes,
        equals([0x12, 0x04, 0x74, 0x65, 0x73, 0x74]),
      );
    });

    test('skips null values', () {
      final encoder = ProtobufEncoder();
      encoder.writeUint32(1, null);
      encoder.writeBytes(2, null);
      encoder.writeString(3, null);
      final bytes = encoder.toBytes();

      expect(bytes, isEmpty);
    });

    test('encodes repeated uint64', () {
      final encoder = ProtobufEncoder();
      encoder.writeRepeatedUint64(4, [10, 20, 30]);
      final bytes = encoder.toBytes();

      // Each value gets its own tag + value
      // Field 4: tag = (4 << 3) | 0 = 0x20
      expect(
        bytes,
        equals([
          0x20, 10, // First value
          0x20, 20, // Second value
          0x20, 30, // Third value
        ]),
      );
    });
  });

  group('UnixFSDataEncoder', () {
    test('encodes file type with no data', () {
      final bytes = UnixFSDataEncoder.encode(
        type: UnixFSDataType.file,
      );

      // Field 1 (Type): tag=0x08, value=2 (file)
      expect(bytes, equals([0x08, 0x02]));
    });

    test('encodes file with data', () {
      final testData = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
      final bytes = UnixFSDataEncoder.encode(
        type: UnixFSDataType.file,
        data: testData,
      );

      // Field 1 (Type): 0x08, 0x02
      // Field 2 (Data): 0x12 (tag), 0x03 (length), 0xAA, 0xBB, 0xCC
      expect(
        bytes,
        equals([0x08, 0x02, 0x12, 0x03, 0xAA, 0xBB, 0xCC]),
      );
    });

    test('encodes file with size and blocksizes', () {
      final bytes = UnixFSDataEncoder.encode(
        type: UnixFSDataType.file,
        filesize: 1000,
        blocksizes: [256, 256, 256, 232],
      );

      // Field 1 (Type): 0x08, 0x02
      // Field 3 (filesize): 0x18, varint(1000) = [0xE8, 0x07]
      // Field 4 (blocksizes): repeated [0x20, value] for each
      expect(bytes[0], equals(0x08)); // Type tag
      expect(bytes[1], equals(0x02)); // File type
      expect(bytes[2], equals(0x18)); // filesize tag
      expect(bytes[3], equals(0xE8)); // 1000 low byte
      expect(bytes[4], equals(0x07)); // 1000 high byte

      // Should have 4 blocksizes entries
      var count = 0;
      for (var i = 5; i < bytes.length; i++) {
        if (bytes[i] == 0x20) count++;
      }
      expect(count, equals(4));
    });

    test('encodes directory type', () {
      final bytes = UnixFSDataEncoder.encode(
        type: UnixFSDataType.directory,
      );

      expect(bytes, equals([0x08, 0x01])); // Type=1 (directory)
    });

    test('encodes raw type', () {
      final bytes = UnixFSDataEncoder.encode(
        type: UnixFSDataType.raw,
      );

      expect(bytes, equals([0x08, 0x00])); // Type=0 (raw)
    });
  });

  group('PBLinkEncoder', () {
    test('encodes link with hash only', () {
      final hash = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final bytes = PBLinkEncoder.encode(hash: hash);

      // Field 1 (Hash): tag=0x0a, length=4, data
      expect(
        bytes,
        equals([0x0a, 0x04, 0x01, 0x02, 0x03, 0x04]),
      );
    });

    test('encodes link with name', () {
      final bytes = PBLinkEncoder.encode(name: 'file.txt');

      // Field 2 (Name): tag=0x12, length=8, UTF-8
      expect(bytes[0], equals(0x12)); // Name tag
      expect(bytes[1], equals(0x08)); // Length 8
      // 'file.txt' in UTF-8
      expect(
        bytes.sublist(2),
        equals([0x66, 0x69, 0x6c, 0x65, 0x2e, 0x74, 0x78, 0x74]),
      );
    });

    test('encodes link with all fields', () {
      final hash = Uint8List.fromList([0xAA, 0xBB]);
      final bytes = PBLinkEncoder.encode(
        hash: hash,
        name: 'test',
        tsize: 100,
      );

      // Should have all three fields encoded
      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(0x0a)); // Hash tag
      // Name and tsize follow
    });

    test('encodes empty link', () {
      final bytes = PBLinkEncoder.encode();

      expect(bytes, isEmpty);
    });
  });

  group('PBNodeEncoder', () {
    test('encodes node with data only', () {
      final data = Uint8List.fromList([0x11, 0x22, 0x33]);
      final bytes = PBNodeEncoder.encode(data: data);

      // Field 1 (Data): tag=0x0a, length=3, data
      expect(
        bytes,
        equals([0x0a, 0x03, 0x11, 0x22, 0x33]),
      );
    });

    test('encodes node with links only', () {
      final link1 = PBLinkEncoder.encode(name: 'a');
      final link2 = PBLinkEncoder.encode(name: 'b');

      final bytes = PBNodeEncoder.encode(
        links: [link1, link2],
      );

      // Should have two link fields (field 2)
      var linkCount = 0;
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] == 0x12) linkCount++; // 0x12 = (2 << 3) | 2
      }
      expect(linkCount, greaterThanOrEqualTo(2));
    });

    test('encodes node with data and links', () {
      final data = Uint8List.fromList([0xFF]);
      final link = PBLinkEncoder.encode(name: 'file');

      final bytes = PBNodeEncoder.encode(
        data: data,
        links: [link],
      );

      // Field 1 (Data) comes first, then Field 2 (Links)
      expect(bytes[0], equals(0x0a)); // Data tag
      expect(bytes, isNotEmpty);
    });

    test('encodes empty node', () {
      final bytes = PBNodeEncoder.encode();

      expect(bytes, isEmpty);
    });
  });

  group('Integration: Complete UnixFS encoding', () {
    test('encodes a simple file node', () {
      // Create UnixFS Data for a file
      final unixfsData = UnixFSDataEncoder.encode(
        type: UnixFSDataType.file,
        filesize: 1024,
      );

      // Wrap in PBNode
      final pbNode = PBNodeEncoder.encode(data: unixfsData);

      expect(pbNode, isNotEmpty);
      expect(pbNode[0], equals(0x0a)); // Data field tag
    });

    test('encodes a chunked file node', () {
      // Create UnixFS Data for chunked file
      final unixfsData = UnixFSDataEncoder.encode(
        type: UnixFSDataType.file,
        filesize: 1000000,
        blocksizes: [256000, 256000, 256000, 232000],
      );

      // Create links to chunks (simulated)
      final links = <Uint8List>[];
      for (var i = 0; i < 4; i++) {
        links.add(
          PBLinkEncoder.encode(
            hash: Uint8List.fromList([i, i, i, i]),
            tsize: i == 3 ? 232000 : 256000,
          ),
        );
      }

      // Wrap in PBNode
      final pbNode = PBNodeEncoder.encode(
        data: unixfsData,
        links: links,
      );

      expect(pbNode, isNotEmpty);
    });

    test('encodes a directory node', () {
      // Create UnixFS Data for directory
      final unixfsData = UnixFSDataEncoder.encode(
        type: UnixFSDataType.directory,
      );

      // Create links to files
      final links = <Uint8List>[
        PBLinkEncoder.encode(
          hash: Uint8List.fromList([0x01]),
          name: 'file1.txt',
          tsize: 100,
        ),
        PBLinkEncoder.encode(
          hash: Uint8List.fromList([0x02]),
          name: 'file2.txt',
          tsize: 200,
        ),
      ];

      // Wrap in PBNode
      final pbNode = PBNodeEncoder.encode(
        data: unixfsData,
        links: links,
      );

      expect(pbNode, isNotEmpty);
      expect(pbNode[0], equals(0x0a)); // Data field
    });
  });
}

