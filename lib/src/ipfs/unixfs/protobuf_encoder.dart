// ignore_for_file: sort_constructors_first

import 'dart:typed_data';

import '../multiformats/varint.dart' as varint;

/// Simple Protobuf encoder for UnixFS messages.
///
/// This is a minimal implementation supporting only the field types
/// needed for UnixFS Data and DAG-PB PBNode/PBLink messages.

/// Protobuf wire types.
enum WireType {
  varint(0), // int32, int64, uint32, uint64, sint32, sint64, bool, enum
  fixed64(1), // fixed64, sfixed64, double
  lengthDelimited(2), // string, bytes, embedded messages, packed repeated
  startGroup(3), // deprecated
  endGroup(4), // deprecated
  fixed32(5); // fixed32, sfixed32, float

  const WireType(this.value);
  final int value;
}

/// A Protobuf field encoder.
class ProtobufEncoder {
  final BytesBuilder _buffer = BytesBuilder();

  /// Encodes a field tag (field number + wire type).
  void _writeTag(int fieldNumber, WireType wireType) {
    final tag = (fieldNumber << 3) | wireType.value;
    _writeVarint(tag);
  }

  /// Writes a varint to the buffer.
  void _writeVarint(int value) {
    final encoded = varint.encode(value);
    _buffer.add(encoded);
  }

  /// Writes bytes directly to the buffer.
  void _writeBytes(List<int> bytes) {
    _buffer.add(bytes);
  }

  /// Encodes an optional uint32 field.
  void writeUint32(int fieldNumber, int? value) {
    if (value == null) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value);
  }

  /// Encodes an optional uint64 field.
  void writeUint64(int fieldNumber, int? value) {
    if (value == null) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value);
  }

  /// Encodes a repeated uint64 field.
  void writeRepeatedUint64(int fieldNumber, List<int> values) {
    for (final value in values) {
      _writeTag(fieldNumber, WireType.varint);
      _writeVarint(value);
    }
  }

  /// Encodes an optional bytes field.
  void writeBytes(int fieldNumber, Uint8List? value) {
    if (value == null || value.isEmpty) return;
    _writeTag(fieldNumber, WireType.lengthDelimited);
    _writeVarint(value.length);
    _writeBytes(value);
  }

  /// Encodes an optional string field.
  void writeString(int fieldNumber, String? value) {
    if (value == null || value.isEmpty) return;
    final bytes = Uint8List.fromList(value.codeUnits);
    _writeTag(fieldNumber, WireType.lengthDelimited);
    _writeVarint(bytes.length);
    _writeBytes(bytes);
  }

  /// Encodes an embedded message field.
  void writeMessage(int fieldNumber, Uint8List? messageBytes) {
    if (messageBytes == null || messageBytes.isEmpty) return;
    _writeTag(fieldNumber, WireType.lengthDelimited);
    _writeVarint(messageBytes.length);
    _writeBytes(messageBytes);
  }

  /// Gets the encoded bytes.
  Uint8List toBytes() => _buffer.toBytes();
}

/// UnixFS Data protobuf encoder.
///
/// message Data {
///   enum DataType {
///     Raw = 0;
///     Directory = 1;
///     File = 2;
///     Metadata = 3;
///     Symlink = 4;
///     HAMTShard = 5;
///   }
///   required DataType Type = 1;
///   optional bytes Data = 2;
///   optional uint64 filesize = 3;
///   repeated uint64 blocksizes = 4;
///   optional uint64 hashType = 5;
///   optional uint64 fanout = 6;
/// }
class UnixFSDataEncoder {
  /// Encodes a UnixFS Data message.
  static Uint8List encode({
    required int type, // DataType enum value
    Uint8List? data,
    int? filesize,
    List<int> blocksizes = const [],
    int? hashType,
    int? fanout,
  }) {
    final encoder = ProtobufEncoder();

    // Field 1: Type (required, but we write it if provided)
    encoder.writeUint32(1, type);

    // Field 2: Data (optional)
    encoder.writeBytes(2, data);

    // Field 3: filesize (optional)
    encoder.writeUint64(3, filesize);

    // Field 4: blocksizes (repeated)
    encoder.writeRepeatedUint64(4, blocksizes);

    // Field 5: hashType (optional)
    encoder.writeUint64(5, hashType);

    // Field 6: fanout (optional)
    encoder.writeUint64(6, fanout);

    return encoder.toBytes();
  }
}

/// DAG-PB PBLink protobuf encoder.
///
/// message PBLink {
///   optional bytes Hash = 1;
///   optional string Name = 2;
///   optional uint64 Tsize = 3;
/// }
class PBLinkEncoder {
  /// Encodes a PBLink message.
  static Uint8List encode({
    Uint8List? hash,
    String? name,
    int? tsize,
  }) {
    final encoder = ProtobufEncoder();

    // Field 1: Hash (optional, CID bytes)
    encoder.writeBytes(1, hash);

    // Field 2: Name (optional)
    encoder.writeString(2, name);

    // Field 3: Tsize (optional, total size)
    encoder.writeUint64(3, tsize);

    return encoder.toBytes();
  }
}

/// DAG-PB PBNode protobuf encoder.
///
/// message PBNode {
///   repeated PBLink Links = 2;
///   optional bytes Data = 1;
/// }
class PBNodeEncoder {
  /// Encodes a PBNode message.
  static Uint8List encode({
    List<Uint8List> links = const [],
    Uint8List? data,
  }) {
    final encoder = ProtobufEncoder();

    // Field 1: Data (optional, UnixFS Data)
    encoder.writeBytes(1, data);

    // Field 2: Links (repeated, encoded PBLinks)
    for (final link in links) {
      encoder.writeMessage(2, link);
    }

    return encoder.toBytes();
  }
}

/// UnixFS DataType enum values.
class UnixFSDataType {
  UnixFSDataType._(); // Prevent instantiation

  static const int raw = 0;
  static const int directory = 1;
  static const int file = 2;
  static const int metadata = 3;
  static const int symlink = 4;
  static const int hamtShard = 5;
}

