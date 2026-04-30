import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';

/// NekoScan (nekoproject.org) implementation of [MangaSourcePlugin].
///
/// NekoScan is a WordPress site using the **mangareader** theme. Manga
/// series are stored as **categories** and chapters as **posts**.
///
/// Hybrid REST + HTML approach:
///
/// - **Search**: WP REST categories (`/wp-json/wp/v2/categories?search=…`).
/// - **Detail + Chapters**: HTML scrape of `/manga/{slug}/` — extracts
///   cover, synopsis, status, type, author, artist, genres, and the
///   chapter list from `<div class="eplister" id="chapterlist">`.
/// - **Pages**: WP REST posts by slug (`/wp-json/wp/v2/posts?slug=…`)
///   — extracts `<img src>` from `content.rendered`.
///
/// [sourceMangaId] is the category slug (e.g. `hana-y-el-hombre-bestia`).
/// [sourceChapterId] is the chapter post slug
/// (e.g. `hana-y-el-hombre-bestia-extra-4`).
final class NekoScanSourcePlugin implements MangaSourcePlugin {
  NekoScanSourcePlugin({http.Client? httpClient, MirrorList? mirrors})
    : _httpClient = httpClient ?? http.Client(),
      _rotator = MirrorRotator(mirrors ?? _defaultMirrors);

  static final MirrorList _defaultMirrors = MirrorList.single(
    Uri.parse('https://nekoproject.org/'),
  );

  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  final http.Client _httpClient;
  final MirrorRotator _rotator;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.nekoscan',
    displayName: 'Neko Scans',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://nekoproject.org'],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        // ES-only catalog. Single scanlator group (Neko Scans).
        supportsLanguageFilter: true,
        supportsScanlatorFilter: false,
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
    List<dynamic> rows;
    try {
      rows = await _rotator.run<List<dynamic>>((base) async {
        final uri = base.replace(
          path: 'wp-json/wp/v2/categories',
          queryParameters: <String, String>{
            'search': query.query,
            'per_page': '${query.limit.clamp(1, 100)}',
            'page': '${query.page.clamp(1, 100)}',
            '_fields': 'id,name,slug,count',
          },
        );
        return _getJsonArray(uri);
      });
    } catch (e) {
      return Failure(_transport('nekoscan.search_transport_failed', e));
    }
    try {
      final matches = rows
          .whereType<Map<String, Object?>>()
          .map(_parseSearchMatch)
          .whereType<SourceMangaMatch>()
          .toList(growable: false);
      return Success(matches);
    } catch (e) {
      return Failure(_err('nekoscan.search_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // latest

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
    final slug = sourceMangaId.trim();
    if (slug.isEmpty) {
      return Failure(
        _err('nekoscan.detail_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    String html;
    try {
      html = await _rotator.run<String>((base) async {
        return _getHtml(base.resolve('manga/$slug/'));
      });
    } catch (e) {
      return Failure(_transport('nekoscan.detail_transport_failed', e));
    }
    try {
      return Success(_parseDetailFromHtml(html, sourceMangaId: slug));
    } catch (e) {
      return Failure(_err('nekoscan.detail_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapters

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    final slug = query.sourceMangaId.trim();
    if (slug.isEmpty) {
      return Failure(
        _err('nekoscan.chapters_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    String html;
    try {
      html = await _rotator.run<String>((base) async {
        return _getHtml(base.resolve('manga/$slug/'));
      });
    } catch (e) {
      return Failure(_transport('nekoscan.chapters_transport_failed', e));
    }
    try {
      final all = _parseChaptersFromHtml(html, sourceMangaId: slug);
      all.sort((a, b) => a.number.compareTo(b.number));
      if (query.scanlators.isEmpty) return Success(all);
      final allowed = query.scanlators.toSet();
      return Success(
        all
            .where((c) => c.scanlator != null && allowed.contains(c.scanlator))
            .toList(growable: false),
      );
    } catch (e) {
      return Failure(_err('nekoscan.chapters_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    final chSlug = chapter.sourceChapterId.trim();
    if (chSlug.isEmpty) {
      return Failure(
        _err('nekoscan.pages_invalid_id', 'sourceChapterId must not be empty'),
      );
    }
    List<dynamic> rows;
    try {
      rows = await _rotator.run<List<dynamic>>((base) async {
        final uri = base.replace(
          path: 'wp-json/wp/v2/posts',
          queryParameters: <String, String>{
            'slug': chSlug,
            '_fields': 'id,content',
          },
        );
        return _getJsonArray(uri);
      });
    } catch (e) {
      return Failure(_transport('nekoscan.pages_transport_failed', e));
    }
    if (rows.isEmpty) {
      return Failure(
        _err('nekoscan.pages_not_found', 'No post found for slug "$chSlug".'),
      );
    }
    final post = rows.first;
    if (post is! Map<String, Object?>) {
      return Failure(
        _err('nekoscan.pages_bad_envelope', 'Post is not a JSON object.'),
      );
    }
    final content = (post['content'] as Map<String, Object?>?)?['rendered'];
    if (content is! String || content.isEmpty) {
      return Failure(
        _err(
          'nekoscan.pages_empty',
          'Chapter post "$chSlug" has no rendered content.',
        ),
      );
    }
    final urls = _extractImageUrls(content);
    if (urls.isEmpty) {
      return Failure(
        _err(
          'nekoscan.pages_empty',
          'No <img src="…"> tags found in chapter post "$chSlug".',
        ),
      );
    }
    final pages = <SourcePage>[];
    for (var i = 0; i < urls.length; i++) {
      final uri = Uri.tryParse(urls[i]);
      if (uri == null) continue;
      pages.add(SourcePage(index: i, imageUrl: uri));
    }
    return Success(pages);
  }

  // ---------------------------------------------------------------------------
  // helpers — http

  Future<dynamic> _getJson(Uri uri) async {
    final res = await _httpClient.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'es,en;q=0.8',
        'User-Agent': _userAgent,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('GET $uri returned ${res.statusCode}', uri);
    }
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> _getJsonArray(Uri uri) async {
    final v = await _getJson(uri);
    if (v is! List) {
      throw FormatException(
        'Expected JSON array; got ${v.runtimeType} for $uri',
      );
    }
    return v;
  }

  Future<String> _getHtml(Uri uri) async {
    final res = await _httpClient.get(
      uri,
      headers: const {
        'Accept': 'text/html',
        'Accept-Language': 'es,en;q=0.8',
        'User-Agent': _userAgent,
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('GET $uri returned ${res.statusCode}', uri);
    }
    return res.body;
  }

  // ---------------------------------------------------------------------------
  // helpers — search parsing

  SourceMangaMatch? _parseSearchMatch(Map<String, Object?> row) {
    final slug = _readString(row['slug']);
    if (slug == null) return null;
    final name = _readString(row['name']);
    if (name == null) return null;
    return SourceMangaMatch(
      sourceId: slug,
      title: _decodeEntities(name),
      format: MangaFormat.unknown,
    );
  }

  // ---------------------------------------------------------------------------
  // helpers — HTML detail parsing

  SourceMangaDetail _parseDetailFromHtml(
    String html, {
    required String sourceMangaId,
  }) {
    // Title
    final titleMatch = _reTitle.firstMatch(html);
    final title = titleMatch != null
        ? _decodeEntities(_stripTags(titleMatch.group(1)!).trim())
        : sourceMangaId;

    // Cover image
    final coverMatch = _reCover.firstMatch(html);
    final coverUrl = coverMatch != null
        ? Uri.tryParse(coverMatch.group(1)!)
        : null;

    // Synopsis
    final synopsisMatch = _reSynopsis.firstMatch(html);
    final synopsis = synopsisMatch != null
        ? _decodeEntities(_stripTags(synopsisMatch.group(1)!).trim())
        : null;

    // Status
    final statusMatch = _reStatus.firstMatch(html);
    final status = _mapStatus(statusMatch?.group(1)?.trim());

    // Type
    final typeMatch = _reType.firstMatch(html);
    final type = typeMatch?.group(1)?.trim();

    // Author
    final authorMatch = _reAuthor.firstMatch(html);
    final author = authorMatch?.group(1)?.trim();

    // Artist
    final artistMatch = _reArtist.firstMatch(html);
    final artist = artistMatch?.group(1)?.trim();

    // Alternative titles
    final altMatch = _reAlt.firstMatch(html);
    final aliases = <String>[];
    if (altMatch != null) {
      final raw = _decodeEntities(altMatch.group(1)!.trim());
      for (final a in raw.split(',')) {
        final trimmed = a.trim();
        if (trimmed.isNotEmpty) aliases.add(trimmed);
      }
    }

    // Genres
    final genres = <String>[
      for (final m in _reGenre.allMatches(html)) _decodeEntities(m.group(1)!),
    ];

    return SourceMangaDetail(
      sourceId: sourceMangaId,
      title: title,
      synopsis: synopsis != null && synopsis.isNotEmpty ? synopsis : null,
      aliases: aliases,
      thumbnailUrl: coverUrl,
      authors: <String>[if (author != null && author.isNotEmpty) author],
      artists: <String>[if (artist != null && artist.isNotEmpty) artist],
      tags: genres,
      status: status,
      format: _mapFormat(type),
      country: _countryFromFormat(type),
      originalLanguage: 'ja',
    );
  }

  // ---------------------------------------------------------------------------
  // helpers — HTML chapter parsing

  List<SourceChapter> _parseChaptersFromHtml(
    String html, {
    required String sourceMangaId,
  }) {
    final chapters = <SourceChapter>[];
    for (final m in _reChapterItem.allMatches(html)) {
      final dataNum = m.group(1)!;
      final href = m.group(2)!;
      final chapterTitle = _cleanChapterTitle(m.group(3)!);
      final dateStr = m.group(4)?.trim();

      // Extract slug from href
      final slug = _slugFromUrl(href);
      if (slug == null) continue;

      // Parse chapter number from data-num attribute
      final number = _parseChapterNumber(dataNum, chapterTitle);
      if (number == null) continue;

      final publishedAt = dateStr != null ? _parseSpanishDate(dateStr) : null;

      chapters.add(
        SourceChapter(
          sourceMangaId: sourceMangaId,
          sourceChapterId: slug,
          number: number,
          title: chapterTitle,
          language: 'es',
          scanlator: 'Neko Scans',
          publishedAt: publishedAt,
        ),
      );
    }
    return chapters;
  }

  // ---------------------------------------------------------------------------
  // helpers — image extraction

  List<String> _extractImageUrls(String html) {
    final re = RegExp(
      '<img[^>]+src=["'
      "'"
      ']([^"'
      "'"
      ']+)["'
      "'"
      ']',
      caseSensitive: false,
    );
    return [
      for (final m in re.allMatches(html))
        if (m.group(1) != null &&
            !m.group(1)!.contains('wp-content/themes/') &&
            !m.group(1)!.contains('wp-includes/'))
          m.group(1)!,
    ];
  }

  // ---------------------------------------------------------------------------
  // helpers — micro

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _cleanChapterTitle(String raw) => _decodeEntities(
    _stripTags(raw),
  ).replaceAll(RegExp(r'\s+-\s*$'), '').trim();

  static String _decodeEntities(String s) => s
      .replaceAll('&#8217;', '\u2019')
      .replaceAll('&#8220;', '\u201c')
      .replaceAll('&#8221;', '\u201d')
      .replaceAll('&#x1f51e;', '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', '\'')
      .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '')
      .trim();

  static MangaStatus _mapStatus(String? raw) {
    if (raw == null) return MangaStatus.unknown;
    final v = raw.toLowerCase();
    if (v == 'ongoing' || v.contains('publicación') || v.contains('emisi')) {
      return MangaStatus.releasing;
    }
    if (v == 'completed' || v.contains('finaliz') || v.contains('completad')) {
      return MangaStatus.finished;
    }
    if (v.contains('hiatus') || v.contains('pausad')) return MangaStatus.hiatus;
    if (v.contains('cancel')) return MangaStatus.cancelled;
    return MangaStatus.unknown;
  }

  static MangaFormat _mapFormat(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'manhwa':
        return MangaFormat.manhwa;
      case 'manhua':
        return MangaFormat.manhua;
      case 'manga':
        return MangaFormat.manga;
      case 'one-shot':
      case 'one shot':
      case 'oneshot':
        return MangaFormat.oneShot;
    }
    return MangaFormat.unknown;
  }

  static MangaCountryOfOrigin? _countryFromFormat(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'manhwa':
        return MangaCountryOfOrigin.kr;
      case 'manhua':
        return MangaCountryOfOrigin.cn;
      case 'manga':
        return MangaCountryOfOrigin.jp;
    }
    return null;
  }

  /// Extracts a post slug from a full NekoScan URL.
  /// e.g. `https://nekoproject.org/hana-y-el-hombre-bestia-extra-4/` → `hana-y-el-hombre-bestia-extra-4`
  static String? _slugFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    // Path segments, ignoring empty strings from trailing slashes.
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return segments.last;
  }

  /// Parses a chapter number from the `data-num` attribute or from the
  /// chapter title string.
  ///
  /// Examples of `data-num`: `"Extra 4"`, `"39 ②"`, `"37.5"`, `"38 RAW"`.
  /// Examples of titles: `"Capítulo 39 ②"`, `"Capítulo Extra 4"`,
  ///   `"Capítulo 37.7 - Final Volumen 7"`.
  static double? _parseChapterNumber(String dataNum, String title) {
    // Try direct parse of data-num
    final direct = double.tryParse(dataNum.trim());
    if (direct != null) return direct;

    // Try to extract a leading number from data-num
    final numMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(dataNum);
    if (numMatch != null) return double.tryParse(numMatch.group(1)!);

    // Fallback: extract from title
    final titleMatch = RegExp(
      r'(?:Cap[ií]tulo|Chapter|Cap)\s+(\d+(?:\.\d+)?)',
    ).firstMatch(title);
    if (titleMatch != null) return double.tryParse(titleMatch.group(1)!);

    return null;
  }

  /// Parses Spanish month-day-year date strings like `"abril 12, 2023"`.
  static DateTime? _parseSpanishDate(String raw) {
    final m = RegExp(r'(\w+)\s+(\d{1,2}),\s*(\d{4})').firstMatch(raw);
    if (m == null) return null;
    final month = _spanishMonth(m.group(1)!.toLowerCase());
    if (month == 0) return null;
    final day = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || year == null) return null;
    return DateTime.utc(year, month, day);
  }

  static int _spanishMonth(String m) {
    const months = <String, int>{
      'enero': 1,
      'febrero': 2,
      'marzo': 3,
      'abril': 4,
      'mayo': 5,
      'junio': 6,
      'julio': 7,
      'agosto': 8,
      'septiembre': 9,
      'octubre': 10,
      'noviembre': 11,
      'diciembre': 12,
    };
    return months[m] ?? 0;
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

  // ---------------------------------------------------------------------------
  // compiled regexes

  static final _reTitle = RegExp(
    r'<h1[^>]*class="entry-title"[^>]*>(.*?)</h1>',
    caseSensitive: false,
    dotAll: true,
  );

  static final _reCover = RegExp(
    r'class="thumb"[^>]*>.*?<img[^>]+src="([^"]+)"',
    caseSensitive: false,
    dotAll: true,
  );

  static final _reSynopsis = RegExp(
    r'class="resdescp"[^>]*>(.*?)</div>',
    caseSensitive: false,
    dotAll: true,
  );

  static final _reStatus = RegExp(
    r'Estado\s*<i>([^<]+)</i>',
    caseSensitive: false,
  );

  static final _reType = RegExp(
    r'Tipo\s*<a[^>]*>([^<]+)</a>',
    caseSensitive: false,
  );

  static final _reAuthor = RegExp(
    r'Autor\s*<i>([^<]+)</i>',
    caseSensitive: false,
  );

  static final _reArtist = RegExp(
    r'Artista\s*<i>([^<]+)</i>',
    caseSensitive: false,
  );

  static final _reAlt = RegExp(
    r'class="alternative">([^<]+)</span>',
    caseSensitive: false,
  );

  static final _reGenre = RegExp(
    r'<a href="https?://[^"]+/genres/[^"]+"[^>]*rel="tag">([^<]+)</a>',
    caseSensitive: false,
  );

  /// Matches chapter items in the `<div class="eplister">` list.
  ///
  /// Capture groups:
  /// 1. `data-num` value
  /// 2. Chapter `href`
  /// 3. `chapternum` span content
  /// 4. `chapterdate` span content
  static final _reChapterItem = RegExp(
    r'<li\s+data-num="([^"]*)"[^>]*>.*?'
    r'<a\s+href="([^"]+)"[^>]*>\s*'
    r'<span\s+class="chapternum">(.*?)</span>\s*'
    r'<span\s+class="chapterdate">([^<]*)</span>',
    caseSensitive: false,
    dotAll: true,
  );
}
