import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/manga_downloads/domain/cbz_packer.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

Future<File> _writeTempPage(Directory dir, int idx, List<int> bytes) async {
  final f = File('${dir.path}/page_$idx.jpg');
  await f.writeAsBytes(bytes);
  return f;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cbz_packer_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('pack writes a CBZ with all pages plus metadata.json', () async {
    final p0 = await _writeTempPage(tmp, 0, const [1, 2, 3]);
    final p1 = await _writeTempPage(tmp, 1, const [4, 5, 6]);
    final p2 = await _writeTempPage(tmp, 2, const [7, 8, 9]);
    final out = File('${tmp.path}/chapter.cbz');

    final result = await CbzPacker.pack(
      targetCbzFile: out,
      pages: [
        CbzPagePart(pageIndex: 0, localFile: p0, fileExtension: 'jpg'),
        CbzPagePart(pageIndex: 1, localFile: p1, fileExtension: 'jpg'),
        CbzPagePart(pageIndex: 2, localFile: p2, fileExtension: 'jpg'),
      ],
      metadata: {
        'manga_anilist_id': 42,
        'chapter_number': 3.5,
        'source_id': 'mangadex',
      },
    );

    expect(result.isSuccess, isTrue, reason: 'pack should succeed');
    expect(await out.exists(), isTrue);

    // Verify entries: 3 pages + metadata.json, all stored uncompressed,
    // pages renamed in render order with zero-padded prefixes.
    final archive = ZipDecoder().decodeBytes(await out.readAsBytes());
    final names = archive.files.map((f) => f.name).toList()..sort();
    expect(names, ['000.jpg', '001.jpg', '002.jpg', 'metadata.json']);
    final p0Entry = archive.files.firstWhere((f) => f.name == '000.jpg');
    expect(p0Entry.content as List<int>, const [1, 2, 3]);
    final meta = archive.files.firstWhere((f) => f.name == 'metadata.json');
    final metaText = String.fromCharCodes(meta.content as List<int>);
    expect(metaText, contains('"manga_anilist_id":42'));
    expect(metaText, contains('"source_id":"mangadex"'));
  });

  test('pack rejects an empty page list', () async {
    final out = File('${tmp.path}/empty.cbz');
    final result = await CbzPacker.pack(
      targetCbzFile: out,
      pages: const <CbzPagePart>[],
      metadata: const <String, Object?>{},
    );
    expect(result.isFailure, isTrue);
    expect((result as Failure).error.code, 'manga_downloads.cbz_empty');
    expect(await out.exists(), isFalse);
  });

  test('pack rejects index gaps to avoid silently dropping pages', () async {
    final p0 = await _writeTempPage(tmp, 0, const [1]);
    final p2 = await _writeTempPage(tmp, 2, const [2]);
    final out = File('${tmp.path}/gap.cbz');

    final result = await CbzPacker.pack(
      targetCbzFile: out,
      pages: [
        CbzPagePart(pageIndex: 0, localFile: p0, fileExtension: 'jpg'),
        CbzPagePart(pageIndex: 2, localFile: p2, fileExtension: 'jpg'),
      ],
      metadata: const <String, Object?>{},
    );

    expect(result.isFailure, isTrue);
    expect((result as Failure).error.code, 'manga_downloads.cbz_gap');
  });

  test('pack fails when a page file is missing on disk', () async {
    final p0 = await _writeTempPage(tmp, 0, const [1]);
    final missing = File('${tmp.path}/missing.jpg');
    final out = File('${tmp.path}/missing.cbz');

    final result = await CbzPacker.pack(
      targetCbzFile: out,
      pages: [
        CbzPagePart(pageIndex: 0, localFile: p0, fileExtension: 'jpg'),
        CbzPagePart(pageIndex: 1, localFile: missing, fileExtension: 'jpg'),
      ],
      metadata: const <String, Object?>{},
    );

    expect(result.isFailure, isTrue);
    expect((result as Failure).error.code, 'manga_downloads.cbz_page_missing');
  });
}
