import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';

/// InManga (`https://inmanga.com`) implementation of [MangaSourcePlugin].
///
/// InManga is an ASP.NET MVC site with a quirky JSON envelope
/// (`{"data": "<inner-json-string>"}` — the value at `data` is itself
/// a JSON string that requires a second `jsonDecode`). Chapter list and
/// search both use this shape.
///
/// Detail metadata (synopsis, status text, cover) and chapter page
/// UUIDs are not exposed via JSON — they're rendered into the SSR HTML.
/// We scrape the public HTML pages for those.
///
/// `sourceMangaId` is the lowercase manga UUID. `sourceChapterId` is
/// the lowercase chapter UUID. The slug segment in the user-facing URL
/// (`/ver/manga/{slug}/...`) is SEO-only; the controller routes by
/// UUID, so we pass `_` as a placeholder and never depend on the slug.
final class InMangaSourcePlugin implements MangaSourcePlugin {
  /// Builds the plugin.
  ///
  /// [mirrors] overrides the default base URL (mostly for tests). The
  /// rotator stays in place for parity with sibling source plugins
  /// even though InManga only has one canonical host today.
  InMangaSourcePlugin({http.Client? httpClient, MirrorList? mirrors})
    : _httpClient = httpClient ?? http.Client(),
      _rotator = MirrorRotator(mirrors ?? _defaultMirrors);

  static final MirrorList _defaultMirrors = MirrorList.single(
    Uri.parse('https://inmanga.com/'),
  );

  // Realistic UA — InManga itself is open but its CDN occasionally
  // 403s requests with default Dart UA strings.
  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  // Page CDN host. The image URL pattern is
  //   https://cdn1.intomanga.com/i/m/{mangaUuid}/c/{chapterUuid}/o/{pageUuid}.jpg
  static const _cdnBase = 'https://cdn1.intomanga.com/i/m';

  final http.Client _httpClient;
  final MirrorRotator _rotator;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.inmanga',
    displayName: 'InManga',
    type: PluginType.source,
    iconUrl: 'https://inmanga.com/content/img/logoMin.png',
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://inmanga.com'],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        // Single language (es) and single scanlator (InManga in-house),
        // but expose the flags so the picker UI doesn't pretend the
        // dimensions don't exist.
        supportsLanguageFilter: true,
        supportsScanlatorFilter: true,
        supportsLatestFeed: false,
        requiresPageHeaders: false,
      );

  // ---------------------------------------------------------------------------
  // search

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  ) async {
    if (query.query.trim().isEmpty) {
      return const Success(<SourceMangaMatch>[]);
    }
    Map<String, Object?> envelope;
    try {
      envelope = await _rotator.run<Map<String, Object?>>((base) async {
        final uri = base.replace(
          path: 'manga/GetQuickSearch',
          queryParameters: <String, String>{'name': query.query},
        );
        return _getEnvelope(uri);
      });
    } catch (e) {
      return Failure(_transport('inmanga.search_transport_failed', e));
    }
    final inner = _readInner(envelope);
    if (inner == null) {
      return Failure(
        _err(
          'inmanga.search_bad_envelope',
          'GetQuickSearch envelope missing or malformed.',
        ),
      );
    }
    final result = inner['result'];
    if (result is! List) {
      return const Success(<SourceMangaMatch>[]);
    }
    try {
      final matches = result
          .whereType<Map<String, Object?>>()
          .map(_parseMatch)
          .whereType<SourceMangaMatch>()
          .toList(growable: false);
      // Server-side returns no pagination params; honor `page` & `limit`
      // by skipping client-side. Most queries fit on a single page.
      final offset = (query.page - 1) * query.limit;
      final limit = query.limit.clamp(1, 50);
      return Success(matches.skip(offset).take(limit).toList(growable: false));
    } catch (e) {
      return Failure(_err('inmanga.search_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // latest updates — not exposed by InManga without auth.

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> getLatestUpdates({
    int page = 1,
    int limit = 20,
  }) async {
    return const Success(<SourceMangaMatch>[]);
  }

  // ---------------------------------------------------------------------------
  // detail

  @override
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  ) async {
    final id = sourceMangaId.trim().toLowerCase();
    if (id.isEmpty) {
      return Failure(
        _err('inmanga.detail_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    String body;
    try {
      body = await _rotator.run<String>((base) async {
        final uri = base.resolve('ver/manga/_/$id');
        return _getString(uri);
      });
    } catch (e) {
      return Failure(_transport('inmanga.detail_transport_failed', e));
    }
    try {
      final detail = _parseDetailHtml(body, sourceMangaId: id);
      if (detail == null) {
        return Failure(
          _err(
            'inmanga.detail_not_parseable',
            'Detail page missing the expected metadata block for $id.',
          ),
        );
      }
      return Success(detail);
    } catch (e) {
      return Failure(_err('inmanga.detail_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapters

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    final id = query.sourceMangaId.trim().toLowerCase();
    if (id.isEmpty) {
      return Failure(
        _err('inmanga.chapters_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    Map<String, Object?> envelope;
    try {
      envelope = await _rotator.run<Map<String, Object?>>((base) async {
        final uri = base.replace(
          path: 'chapter/getall',
          queryParameters: <String, String>{'mangaIdentification': id},
        );
        return _getEnvelope(uri);
      });
    } catch (e) {
      return Failure(_transport('inmanga.chapters_transport_failed', e));
    }
    final inner = _readInner(envelope);
    if (inner == null) {
      return Failure(
        _err(
          'inmanga.chapters_bad_envelope',
          'getall envelope missing or malformed.',
        ),
      );
    }
    final result = inner['result'];
    if (result is! List) {
      return const Success(<SourceChapter>[]);
    }
    try {
      final chapters = result
          .whereType<Map<String, Object?>>()
          .map((row) => _parseChapter(row, sourceMangaId: id))
          .whereType<SourceChapter>()
          .toList();
      // InManga returns chapters in numeric-string order which is NOT
      // numeric — `1, 10, 11, …, 2, 20, …`. Re-sort ascending by number
      // so the composite layer + UI see a monotonic list.
      chapters.sort((a, b) => a.number.compareTo(b.number));
      if (query.scanlators.isEmpty) return Success(chapters);
      final allowed = query.scanlators.toSet();
      final filtered = chapters
          .where((c) => c.scanlator != null && allowed.contains(c.scanlator))
          .toList(growable: false);
      return Success(filtered);
    } catch (e) {
      return Failure(_err('inmanga.chapters_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    final chId = chapter.sourceChapterId.trim().toLowerCase();
    final mId = chapter.sourceMangaId.trim().toLowerCase();
    if (chId.isEmpty || mId.isEmpty) {
      return Failure(
        _err(
          'inmanga.pages_invalid_id',
          'sourceChapterId and sourceMangaId must not be empty',
        ),
      );
    }
    String body;
    try {
      // InManga moved the PageList from the main reader page into a
      // separate partial loaded via AJAX. The reader HTML no longer
      // embeds the <select id="PageList"> inline. We now call the
      // same endpoint the JS client uses.
      body = await _rotator.run<String>((base) async {
        final uri = base.replace(
          path: 'chapter/chapterIndexControls',
          queryParameters: <String, String>{'identification': chId},
        );
        return _getString(uri);
      });
    } catch (e) {
      return Failure(_transport('inmanga.pages_transport_failed', e));
    }
    final pageIds = _extractPageIds(body);
    if (pageIds.isEmpty) {
      return Failure(
        _err(
          'inmanga.pages_empty',
          'Reader page did not expose a PageList select for chapter $chId.',
        ),
      );
    }
    final pages = <SourcePage>[];
    for (var i = 0; i < pageIds.length; i++) {
      final pid = pageIds[i].toLowerCase();
      final url = Uri.parse('$_cdnBase/$mId/c/$chId/o/$pid.jpg');
      pages.add(SourcePage(index: i, imageUrl: url));
    }
    return Success(pages);
  }

  // ---------------------------------------------------------------------------
  // helpers — http

  Future<String> _getString(Uri uri) async {
    final res = await _httpClient.get(
      uri,
      headers: const {
        'Accept': 'text/html,application/xhtml+xml,application/json',
        'Accept-Language': 'es,en;q=0.8',
        'User-Agent': _userAgent,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('GET $uri returned ${res.statusCode}', uri);
    }
    return res.body;
  }

  /// Decodes the InManga `{"data": "<inner-json-string>"}` envelope into
  /// the inner object. The envelope itself is plain JSON; the value at
  /// `data` is a string that requires a second decode.
  Future<Map<String, Object?>> _getEnvelope(Uri uri) async {
    final body = await _getString(uri);
    final outer = jsonDecode(body);
    if (outer is! Map<String, Object?>) {
      throw FormatException(
        'Expected outer JSON object; got ${outer.runtimeType} for $uri',
      );
    }
    return outer;
  }

  Map<String, Object?>? _readInner(Map<String, Object?> envelope) {
    final raw = envelope['data'];
    if (raw is! String || raw.isEmpty) return null;
    try {
      final inner = jsonDecode(raw);
      if (inner is Map<String, Object?>) return inner;
    } catch (_) {
      return null;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // helpers — parsing

  SourceMangaMatch? _parseMatch(Map<String, Object?> row) {
    final id = _readString(row['Identification'])?.toLowerCase();
    final name = _readString(row['Name']);
    if (id == null || name == null) return null;
    final cover = _readString(row['ThumbnailPath']);
    final altsRaw = row['AlternativeNames'];
    final aliases = altsRaw is List
        ? altsRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    final year = _readYear(_readString(row['CreationDate']));
    return SourceMangaMatch(
      sourceId: id,
      title: name,
      aliases: aliases,
      thumbnailUrl: cover != null ? Uri.tryParse(cover) : null,
      releaseYear: year,
      format: MangaFormat.unknown,
      country: MangaCountryOfOrigin.jp,
    );
  }

  SourceChapter? _parseChapter(
    Map<String, Object?> row, {
    required String sourceMangaId,
  }) {
    final id = _readString(row['Identification'])?.toLowerCase();
    if (id == null) return null;
    final numberRaw = row['Number'];
    final number = numberRaw is num
        ? numberRaw.toDouble()
        : double.tryParse('${numberRaw ?? ''}');
    if (number == null) return null;
    final pageCount = row['PagesCount'];
    final published = _parseDotnetIso(_readString(row['RegistrationDate']));
    return SourceChapter(
      sourceMangaId: sourceMangaId,
      sourceChapterId: id,
      number: number,
      title: null,
      language: 'es',
      scanlator: 'InManga',
      publishedAt: published,
      pageCount: pageCount is int ? pageCount : null,
    );
  }

  /// Scrapes minimum metadata from the SSR detail HTML page.
  ///
  /// We don't pull in a full HTML parser dependency — the markup is
  /// stable enough that anchor-based string slicing works and keeps
  /// the package tree minimal.
  SourceMangaDetail? _parseDetailHtml(
    String html, {
    required String sourceMangaId,
  }) {
    // `<h1>` may carry attributes; capture the inner text after the
    // opening tag's '>' explicitly.
    final titleMatch = RegExp(r'<h1\b[^>]*>([\s\S]*?)</h1>').firstMatch(html);
    final title = titleMatch == null
        ? null
        : _stripTags(titleMatch.group(1)!).trim();
    if (title == null || title.isEmpty) return null;
    final cover = _matchFirstAttr(
      html,
      RegExp(
        '<img[^>]+src=["'
        "'"
        ']'
        r'(https://inmanga\.com/thumbnails/manga/[^"'
        "'"
        r']+)'
        '["'
        "'"
        ']',
      ),
    );
    final synopsisRaw =
        _between(html, '<div class="synopsis">', '</div>') ??
        _between(html, 'class="panel-body"', '</div>');
    final synopsis = synopsisRaw == null
        ? null
        : _stripTags(synopsisRaw).trim();
    final statusText = _statusFromHtml(html);
    return SourceMangaDetail(
      sourceId: sourceMangaId,
      title: title,
      synopsis: (synopsis != null && synopsis.isNotEmpty) ? synopsis : null,
      thumbnailUrl: cover != null ? Uri.tryParse(cover) : null,
      status: _mapStatus(statusText),
      format: MangaFormat.manga,
      country: MangaCountryOfOrigin.jp,
      originalLanguage: 'ja',
    );
  }

  /// Reads the page UUIDs out of `<select id="PageList">` on a chapter
  /// reader page. Order matters — option iteration order = render order.
  List<String> _extractPageIds(String html) {
    final selectMatch = RegExp(
      r'<select[^>]*id=["'
      "'"
      r']PageList["'
      "'"
      r'][^>]*>([\s\S]*?)</select>',
      caseSensitive: false,
    ).firstMatch(html);
    if (selectMatch == null) return const <String>[];
    final inner = selectMatch.group(1) ?? '';
    final ids = <String>[];
    final optionRe = RegExp(
      r'<option[^>]*value=["'
      "'"
      r']([0-9a-fA-F-]{36})["'
      "'"
      r']',
    );
    for (final m in optionRe.allMatches(inner)) {
      ids.add(m.group(1)!);
    }
    return ids;
  }

  String? _statusFromHtml(String html) {
    // The status sits inside a span that precedes a "Estado" label.
    // We scan for the label and walk back to the previous span content.
    final labelIdx = html.indexOf(' Estado');
    if (labelIdx < 0) {
      // Fallback: just find any "En emisión" / "Finalizado" / etc.
      for (final s in const <String>[
        'En emisión',
        'En Emisión',
        'Finalizado',
        'Cancelado',
        'Pausado',
        'Hiatus',
      ]) {
        if (html.contains(s)) return s;
      }
      return null;
    }
    final upTo = html.substring(0, labelIdx);
    final lastSpanOpen = upTo.lastIndexOf('<span');
    if (lastSpanOpen < 0) return null;
    final tagEnd = upTo.indexOf('>', lastSpanOpen);
    if (tagEnd < 0) return null;
    final closeIdx = upTo.indexOf('</span>', tagEnd);
    if (closeIdx < 0) return null;
    return upTo.substring(tagEnd + 1, closeIdx).trim();
  }

  // ---------------------------------------------------------------------------
  // helpers — micro

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static int? _readYear(String? iso) {
    if (iso == null) return null;
    final m = RegExp(r'^(\d{4})').firstMatch(iso);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Parses ASP.NET-flavored ISO timestamps with sub-second microseconds
  /// (`2016-08-01T21:38:10.0459418`). Dart's `DateTime.tryParse` already
  /// handles this; kept as a named helper for readability.
  static DateTime? _parseDotnetIso(String? v) {
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  static String? _between(String haystack, String start, String end) {
    final s = haystack.indexOf(start);
    if (s < 0) return null;
    final e = haystack.indexOf(end, s + start.length);
    if (e < 0) return null;
    return haystack.substring(s + start.length, e);
  }

  static String? _matchFirstAttr(String html, RegExp re) {
    final m = re.firstMatch(html);
    return m?.group(1);
  }

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  static MangaStatus _mapStatus(String? raw) {
    if (raw == null) return MangaStatus.unknown;
    final v = raw.trim().toLowerCase();
    if (v.startsWith('en emisi')) return MangaStatus.releasing;
    if (v.startsWith('finalizad')) return MangaStatus.finished;
    if (v.contains('hiatus') || v.contains('pausad')) return MangaStatus.hiatus;
    if (v.contains('cancelad')) return MangaStatus.cancelled;
    return MangaStatus.unknown;
  }

  KumoriyaError _err(String code, String message) => SimpleError(
    code: code,
    message: message,
    kind: KumoriyaErrorKind.mapping,
  );

  KumoriyaError _transport(String code, Object error) => SimpleError(
    code: code,
    message: '$error',
    kind: KumoriyaErrorKind.transport,
  );
}
