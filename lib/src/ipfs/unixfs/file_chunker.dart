import 'dart:typed_data';

import '../../upload/blob.dart';

/// Chunks a file into fixed-size pieces for UnixFS encoding.
///
/// This chunker reads from a [BlobLike] stream and yields chunks of
/// [chunkSize] bytes (last chunk may be smaller).
class FileChunker {
  /// Creates a file chunker with the given chunk size.
  const FileChunker({this.chunkSize = 256 * 1024}); // 256 KiB default

  /// Size of each chunk in bytes.
  final int chunkSize;

  /// Chunks the given blob into fixed-size pieces.
  ///
  /// Yields [Uint8List] chunks as they are read from the blob's stream.
  /// The last chunk may be smaller than [chunkSize].
  Stream<Uint8List> chunk(BlobLike blob) async* {
    final buffer = <int>[];

    await for (final piece in blob.stream()) {
      buffer.addAll(piece);

      // Yield complete chunks
      while (buffer.length >= chunkSize) {
        yield Uint8List.fromList(buffer.sublist(0, chunkSize));
        buffer.removeRange(0, chunkSize);
      }
    }

    // Yield remaining data
    if (buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  /// Returns the estimated number of chunks for a given file size.
  ///
  /// This is a ceiling division: `(size + chunkSize - 1) ~/ chunkSize`
  int estimateChunkCount(int fileSize) {
    if (fileSize == 0) return 0;
    return (fileSize + chunkSize - 1) ~/ chunkSize;
  }
}

