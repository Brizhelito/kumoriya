import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:path/path.dart' as p;

/// Pulls a `.cbz` apart into per-page files on disk and exposes them
/// as [MangaPage] objects whose `imageUrl` carries a `file://` URI.
///
/// The reader's [MangaPageImage] knows how to render a `file://` URI
/// via `Image.file`, so the same widget tree handles both online
/// (downloaded-on-demand) and offline (already-on-disk) chapters.
abstract final class CbzUnpacker {
  /// Extracts the archive at [cbzFile] into [extractDir]. Reuses the
  /// directory if it already contains an extraction (cheap re-open
  /// when the user navigates back into a chapter). Returns the
  /// ordered page list.
  static Future<Result<List<MangaPage>, KumoriyaError>> extract({
    required File cbzFile,
    required Directory extractDir,
  }) async {
    if (!await cbzFile.exists()) {
      return Failure(
        SimpleError(
          code: 'manga_downloads.cbz_not_found',
          message: 'CBZ file missing on disk: ${cbzFile.path}',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    try {
      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      }

      final archive = ZipDecoder().decodeBytes(await cbzFile.readAsBytes());
      final pageEntries = archive.files
          .where(
            (f) => f.isFile && f.name != 'metadata.json' && _isImage(f.name),
          )
          .toList();

      if (pageEntries.isEmpty) {
        return Failure(
          const SimpleError(
            code: 'manga_downloads.cbz_no_pages',
            message: 'CBZ archive contains no image pages.',
            kind: KumoriyaErrorKind.notFound,
          ),
        );
      }

      // Page filenames are zero-padded by the packer (see CbzPacker),
      // so a plain string sort yields render order.
      pageEntries.sort((a, b) => a.name.compareTo(b.name));

      final pages = <MangaPage>[];
      for (var i = 0; i < pageEntries.length; i++) {
        final entry = pageEntries[i];
        final outFile = File(p.join(extractDir.path, entry.name));
        // Skip rewrite if the extraction is already complete and the
        // size matches — avoids touching the disk when the user
        // re-opens the same chapter back-to-back.
        final needsWrite =
            !await outFile.exists() || (await outFile.length()) != entry.size;
        if (needsWrite) {
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes((entry.content as List<int>), flush: true);
        }
        pages.add(
          MangaPage(
            index: i,
            imageUrl: Uri.file(outFile.path),
            headers: const <String, String>{},
          ),
        );
      }

      return Success(pages);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'manga_downloads.cbz_unpack_failed',
          message: 'Failed to extract CBZ: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  static bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.avif') ||
        lower.endsWith('.gif');
  }
}
