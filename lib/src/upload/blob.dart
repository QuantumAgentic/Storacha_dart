// ignore_for_file: sort_constructors_first

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A blob-like object that can be streamed and has an optional size.
///
/// This is the Dart equivalent of JavaScript's `BlobLike` interface.
/// It represents binary data that can be uploaded to the Storacha network.
///
/// Example:
/// ```dart
/// final blob = MemoryBlob(
///   bytes: utf8.encode('Hello, Storacha!'),
/// );
/// ```
abstract class BlobLike {
  /// Returns a stream of bytes for this blob.
  ///
  /// The stream should be consumed only once. If you need to read the data
  /// multiple times, consider using [MemoryBlob] or creating multiple
  /// instances.
  Stream<Uint8List> stream();

  /// Size of the blob in bytes, if known.
  ///
  /// Some blob implementations may not know the size upfront (e.g., streams
  /// from network). In such cases, this returns `null`.
  int? get size;
}

/// A file-like object with a name and binary data.
///
/// This extends [BlobLike] with a `name` property, making it suitable for
/// file uploads where the filename is important.
///
/// Example:
/// ```dart
/// final file = MemoryFile(
///   name: 'hello.txt',
///   bytes: utf8.encode('Hello, Storacha!'),
/// );
/// ```
abstract class FileLike implements BlobLike {
  /// Name of the file, may include path information.
  ///
  /// Examples:
  /// - `'document.pdf'`
  /// - `'images/photo.jpg'`
  /// - `'src/main.dart'`
  String get name;
}

/// An in-memory implementation of [BlobLike].
///
/// This implementation stores the entire blob in memory as a [Uint8List].
/// It's suitable for small files or when you have all data available upfront.
///
/// For large files or streaming scenarios, consider implementing a custom
/// [BlobLike] that streams from disk or network.
@immutable
class MemoryBlob implements BlobLike {
  /// Creates a memory-backed blob from bytes.
  const MemoryBlob({required this.bytes});

  /// The blob data in memory.
  final Uint8List bytes;

  @override
  Stream<Uint8List> stream() async* {
    yield bytes;
  }

  @override
  int get size => bytes.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryBlob && _bytesEqual(bytes, other.bytes);

  @override
  int get hashCode => bytes.length.hashCode;

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'MemoryBlob(size: $size bytes)';
}

/// An in-memory implementation of [FileLike].
///
/// This implementation stores the entire file in memory as a [Uint8List].
/// It's suitable for small files or when you have all data available upfront.
///
/// Example:
/// ```dart
/// final file = MemoryFile(
///   name: 'config.json',
///   bytes: utf8.encode('{"version": "1.0"}'),
/// );
///
/// print(file.name); // 'config.json'
/// print(file.size); // 20
/// ```
@immutable
class MemoryFile implements FileLike {
  /// Creates a memory-backed file with a name and bytes.
  const MemoryFile({
    required this.name,
    required this.bytes,
  });

  @override
  final String name;

  /// The file data in memory.
  final Uint8List bytes;

  @override
  Stream<Uint8List> stream() async* {
    yield bytes;
  }

  @override
  int get size => bytes.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryFile &&
          name == other.name &&
          _bytesEqual(bytes, other.bytes);

  @override
  int get hashCode => Object.hash(name, bytes.length);

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'MemoryFile(name: $name, size: $size bytes)';
}
