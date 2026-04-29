import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

/// One source page already on disk, ready to be added to the CBZ archive.
///
/// `pageIndex` is the 0-based render order. The packer renames the stored
/// file inside the archive to `001.<ext>` to make CBZ readers display
/// them in the right order regardless of the original URL.
class CbzPagePart {
  const CbzPagePart({
    required this.pageIndex,
    required this.localFile,
    required this.fileExtension,
  });

  final int pageIndex;
  final File localFile;

  /// Without leading dot. Empty string is rejected — the contract is
  /// "the page already lives on disk with a known extension".
  final String fileExtension;
}

/// Pure CBZ writer. Takes per-page files plus an embedded `metadata.json`
/// blob and produces a `.cbz` archive on disk.
///
/// Stays a static-method utility so the download manager can call it
/// without owning any state. Tests instantiate parts in a temp dir and
/// verify the archive structure.
abstract final class CbzPacker {
  /// Builds the archive at `targetCbzFile`. Overwrites if it already
  /// exists. Returns `Failure` for any I/O or zip error.
  ///
  /// The archive uses [Archive] with `STORE` (no compression) so packing
  /// large image volumes does not block the UI thread for seconds —
  /// images are already JPEG/WebP/PNG, recompressing yields almost
  /// nothing.
  static Future<Result<File, KumoriyaError>> pack({
    required File targetCbzFile,
    required List<CbzPagePart> pages,
    required Map<String, Object?> metadata,
  }) async {
    if (pages.isEmpty) {
      return Failure(
        const SimpleError(
          code: 'manga_downloads.cbz_empty',
          message: 'Cannot create a CBZ with zero pages.',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }

    try {
      // Sort by pageIndex so the rename-to-001 step yields render order.
      final sorted = [...pages]
        ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

      // Defensive: detect index gaps. The reader treats them as missing
      // pages, which would silently produce an incomplete CBZ.
      for (var i = 0; i < sorted.length; i++) {
        if (sorted[i].pageIndex != i) {
          return Failure(
            SimpleError(
              code: 'manga_downloads.cbz_gap',
              message:
                  'Page index gap: expected $i, got ${sorted[i].pageIndex}.',
              kind: KumoriyaErrorKind.unexpected,
            ),
          );
        }
      }

      final archive = Archive();

      // Width of the zero-padded prefix scales with page count so 100+
      // pages still sort lexicographically.
      final padWidth = sorted.length.toString().length.clamp(3, 5);

      for (final page in sorted) {
        if (!await page.localFile.exists()) {
          return Failure(
            SimpleError(
              code: 'manga_downloads.cbz_page_missing',
              message:
                  'Page ${page.pageIndex} file not found: '
                  '${page.localFile.path}',
              kind: KumoriyaErrorKind.notFound,
            ),
          );
        }
        final bytes = await page.localFile.readAsBytes();
        final ext = page.fileExtension.replaceFirst(RegExp(r'^\.'), '');
        if (ext.isEmpty) {
          return Failure(
            SimpleError(
              code: 'manga_downloads.cbz_bad_extension',
              message: 'Page ${page.pageIndex} has empty extension.',
              kind: KumoriyaErrorKind.unexpected,
            ),
          );
        }
        final entryName =
            '${page.pageIndex.toString().padLeft(padWidth, '0')}.$ext';
        archive.addFile(
          ArchiveFile(entryName, bytes.length, bytes)
            ..compression = CompressionType.none, // STORE — see method doc.
        );
      }

      // Embed sidecar metadata so future tooling (and the reader's local
      // path) can read titles, source ids, and chapter numbers without
      // hitting the database.
      final metaJson = _encodeMeta(metadata);
      final metaBytes = Uint8List.fromList(metaJson.codeUnits);
      archive.addFile(
        ArchiveFile('metadata.json', metaBytes.length, metaBytes)
          ..compression = CompressionType.none,
      );

      // Atomic write: serialize to a temp file in the same dir, fsync,
      // then rename. Prevents partial CBZs from being indexed if the
      // process dies mid-write.
      final tempPath = '${targetCbzFile.path}.part';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      final encoded = ZipEncoder().encode(archive);
      await tempFile.writeAsBytes(encoded, flush: true);
      if (await targetCbzFile.exists()) {
        await targetCbzFile.delete();
      }
      await tempFile.rename(targetCbzFile.path);
      return Success(targetCbzFile);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'manga_downloads.cbz_pack_failed',
          message: 'Failed to pack CBZ: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  /// Minimal JSON encoder for the metadata side-car. Avoids pulling in a
  /// full JSON dep just for one map; values are coerced to strings.
  /// Strings with `"` or `\\` are escaped.
  static String _encodeMeta(Map<String, Object?> map) {
    final buf = StringBuffer('{');
    var first = true;
    map.forEach((k, v) {
      if (!first) buf.write(',');
      first = false;
      buf
        ..write('"')
        ..write(_escape(k))
        ..write('":');
      if (v == null) {
        buf.write('null');
      } else if (v is num || v is bool) {
        buf.write(v.toString());
      } else {
        buf
          ..write('"')
          ..write(_escape(v.toString()))
          ..write('"');
      }
    });
    buf.write('}');
    return buf.toString();
  }

  static String _escape(String s) {
    return s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
