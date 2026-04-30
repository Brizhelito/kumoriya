import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';

/// Visor TMO Manga (`visormanga.com`) implementation of [MangaSourcePlugin].
///
/// The site has no public REST API. Every surface is rendered server-side
/// HTML against a Laravel backend. The plugin scrapes:
///
/// - **Search**: `GET /biblioteca?search={q}&page={p}` — anchor list of
///   `<a href="/manga/{slug}">` cards.
/// - **Detail + chapters**: `GET /manga/{slug}` — single round-trip that
///   contains title, year, cover, type label, genres, synopsis and the
///   full chapter list (`<li class="li-manga-chapter">`).
/// - **Pages**: `GET /leer/{slug}-{N.NN}` — chapter images embedded
///   inside `<div id="image-alls">`.
///
/// [sourceMangaId] is the manga slug (e.g. `dios-te-bendiga`).
/// [sourceChapterId] is the URL-shaped chapter number (e.g. `43.00`),
/// preserved verbatim so the plugin can rebuild the reader URL without a
/// secondary lookup.
final class VisorMangaSourcePlugin implements MangaSourcePlugin {
  VisorMangaSourcePlugin({http.Client? httpClient, MirrorList? mirrors})
    : _httpClient = httpClient ?? http.Client(),
      _rotator = MirrorRotator(mirrors ?? _defaultMirrors);

  static final MirrorList _defaultMirrors = MirrorList.single(
    Uri.parse('https://visormanga.com/'),
  );

  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  final http.Client _httpClient;
  final MirrorRotator _rotator;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.visormanga',
    displayName: 'Visor TMO Manga',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://visormanga.com'],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
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
    String html;
    try {
      html = await _rotator.run<String>((base) async {
        final uri = base.replace(
          path: 'biblioteca',
          queryParameters: <String, String>{
            'search': query.query,
            'page': '${query.page.clamp(1, 9999)}',
          },
        );
        return _getHtml(uri);
      });
    } catch (e) {
      return Failure(_transport('visormanga.search_transport_failed', e));
    }
    try {
      final matches = _parseSearchResults(html, limit: query.limit);
      return Success(matches);
    } catch (e) {
      return Failure(_err('visormanga.search_parse_failed', '$e'));
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
        _err('visormanga.detail_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    String html;
    try {
      html = await _rotator.run<String>((base) async {
        return _getHtml(base.resolve('manga/$slug'));
      });
    } catch (e) {
      return Failure(_transport('visormanga.detail_transport_failed', e));
    }
    try {
      return Success(_parseDetailFromHtml(html, sourceMangaId: slug));
    } catch (e) {
      return Failure(_err('visormanga.detail_parse_failed', '$e'));
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
        _err(
          'visormanga.chapters_invalid_id',
          'sourceMangaId must not be empty',
        ),
      );
    }
    String html;
    try {
      html = await _rotator.run<String>((base) async {
        return _getHtml(base.resolve('manga/$slug'));
      });
    } catch (e) {
      return Failure(_transport('visormanga.chapters_transport_failed', e));
    }
    try {
      final all = _parseChaptersFromHtml(html, sourceMangaId: slug);
      all.sort((a, b) => a.number.compareTo(b.number));
      return Success(all);
    } catch (e) {
      return Failure(_err('visormanga.chapters_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    final slug = chapter.sourceMangaId.trim();
    final chId = chapter.sourceChapterId.trim();
    if (slug.isEmpty || chId.isEmpty) {
      return Failure(
        _err(
          'visormanga.pages_invalid_id',
          'sourceMangaId and sourceChapterId must not be empty',
        ),
      );
    }
    String html;
    try {
      html = await _rotator.run<String>((base) async {
        return _getHtml(base.resolve('leer/$slug-$chId'));
      });
    } catch (e) {
      return Failure(_transport('visormanga.pages_transport_failed', e));
    }
    final block = _reImageAlls.firstMatch(html);
    if (block == null) {
      return Failure(
        _err(
          'visormanga.pages_block_missing',
          'No <div id="image-alls"> block found in reader HTML.',
        ),
      );
    }
    final inner = block.group(1) ?? '';
    if (inner.toLowerCase().contains('no hay imagenes disponibles')) {
      return Failure(
        _err(
          'visormanga.pages_unavailable',
          'Site reports the chapter has no available images yet.',
        ),
      );
    }
    final urls = <String>[
      for (final m in _reReaderImg.allMatches(inner))
        if (m.group(1) != null) m.group(1)!,
    ];
    if (urls.isEmpty) {
      return Failure(
        _err(
          'visormanga.pages_empty',
          'No <img src="…"> tags found inside <div id="image-alls">.',
        ),
      );
    }
    final pages = <SourcePage>[];
    for (var i = 0; i < urls.length; i++) {
      final uri = Uri.tryParse(urls[i]);
      if (uri == null) continue;
      pages.add(SourcePage(index: pages.length, imageUrl: uri));
    }
    if (pages.isEmpty) {
      return Failure(
        _err('visormanga.pages_empty', 'Reader image URLs were not parseable.'),
      );
    }
    return Success(pages);
  }

  // ---------------------------------------------------------------------------
  // helpers — http

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

  List<SourceMangaMatch> _parseSearchResults(
    String html, {
    required int limit,
  }) {
    final matches = <SourceMangaMatch>[];
    final seen = <String>{};
    for (final m in _reSearchCard.allMatches(html)) {
      if (matches.length >= limit) break;
      final url = m.group(1);
      final inner = m.group(2);
      if (url == null || inner == null) continue;
      final slug = _slugFromMangaUrl(url);
      if (slug == null || !seen.add(slug)) continue;

      final coverMatch = _reCardImg.firstMatch(inner);
      final coverUri = coverMatch != null
          ? Uri.tryParse(coverMatch.group(1)!)
          : null;
      final typeMatch = _reCardType.firstMatch(inner);
      final type = typeMatch?.group(1)?.trim();
      final titleMatch = _reCardTitle.firstMatch(inner);
      final title = titleMatch != null
          ? _decodeEntities(titleMatch.group(1)!.trim())
          : _humanizeSlug(slug);

      matches.add(
        SourceMangaMatch(
          sourceId: slug,
          title: title,
          thumbnailUrl: coverUri,
          format: _mapFormat(type),
          country: _countryFromFormat(type),
        ),
      );
    }
    return matches;
  }

  // ---------------------------------------------------------------------------
  // helpers — HTML detail parsing

  SourceMangaDetail _parseDetailFromHtml(
    String html, {
    required String sourceMangaId,
  }) {
    final titleMatch = _reTitle.firstMatch(html);
    String? rawTitle;
    int? year;
    if (titleMatch != null) {
      rawTitle = _decodeEntities(_stripTags(titleMatch.group(1)!).trim());
      final yearMatch = _reYear.firstMatch(rawTitle);
      if (yearMatch != null) {
        year = int.tryParse(yearMatch.group(1)!);
        rawTitle = rawTitle.replaceFirst(yearMatch.group(0)!, '').trim();
      }
    }
    final title = rawTitle ?? _humanizeSlug(sourceMangaId);

    final coverMatch = _reCover.firstMatch(html);
    final coverUri = coverMatch != null
        ? Uri.tryParse(coverMatch.group(1)!)
        : null;

    final typeMatch = _reType.firstMatch(html);
    final type = typeMatch?.group(1)?.trim();

    final synopsisMatch = _reSynopsis.firstMatch(html);
    final synopsis = synopsisMatch != null
        ? _decodeEntities(_stripTags(synopsisMatch.group(1)!).trim())
        : null;

    final genres = <String>[
      for (final m in _reGenre.allMatches(html))
        _decodeEntities(m.group(1)!.trim()),
    ];

    return SourceMangaDetail(
      sourceId: sourceMangaId,
      title: title,
      synopsis: synopsis != null && synopsis.isNotEmpty ? synopsis : null,
      thumbnailUrl: coverUri,
      tags: genres,
      releaseYear: year,
      format: _mapFormat(type),
      country: _countryFromFormat(type),
      originalLanguage: _languageFromFormat(type),
    );
  }

  // ---------------------------------------------------------------------------
  // helpers — HTML chapter parsing

  List<SourceChapter> _parseChaptersFromHtml(
    String html, {
    required String sourceMangaId,
  }) {
    final chapters = <SourceChapter>[];
    final seen = <String>{};
    for (final m in _reChapter.allMatches(html)) {
      final href = m.group(1);
      if (href == null) continue;
      final urlNumber = _readerNumber(href);
      if (urlNumber == null) continue;
      // Two-decimal id used in URLs (e.g. `43.00`).
      final chapterId = urlNumber;
      if (!seen.add(chapterId)) continue;

      final number = double.tryParse(urlNumber);
      if (number == null) continue;

      chapters.add(
        SourceChapter(
          sourceMangaId: sourceMangaId,
          sourceChapterId: chapterId,
          number: number,
          language: 'es',
          scanlator: 'Visor TMO Manga',
        ),
      );
    }
    return chapters;
  }

  // ---------------------------------------------------------------------------
  // helpers — micro

  static String? _slugFromMangaUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 2) return null;
    if (segments[segments.length - 2] != 'manga') return null;
    return segments.last;
  }

  /// Extracts the trailing chapter number from a `/leer/{slug}-{N.NN}` URL.
  static String? _readerNumber(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.first != 'leer') return null;
    final tail = segments.last;
    final m = RegExp(r'-(\d+(?:\.\d+)?)$').firstMatch(tail);
    return m?.group(1);
  }

  static String _humanizeSlug(String slug) => slug.replaceAll('-', ' ').trim();

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  static String _decodeEntities(String s) => s
      .replaceAll('&#8217;', '\u2019')
      .replaceAll('&#8220;', '\u201c')
      .replaceAll('&#8221;', '\u201d')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', '\'')
      .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

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

  static String? _languageFromFormat(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'manhwa':
        return 'ko';
      case 'manhua':
        return 'zh';
      case 'manga':
        return 'ja';
    }
    return null;
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

  /// Search card anchor: captures the manga URL and the inner content
  /// (which holds the cover image, type span and the title).
  static final _reSearchCard = RegExp(
    r'<a[^>]+href="(https?://[^"/]+/manga/[^"]+)"[^>]*>([\s\S]*?)</a>',
    caseSensitive: false,
  );

  static final _reCardImg = RegExp(
    r'<img[^>]+(?:data-src|src)="([^"]+)"',
    caseSensitive: false,
  );

  static final _reCardType = RegExp(
    r'<span[^>]*class="(?:type-manga|manga-type-updated)[^"]*"[^>]*>\s*([^<]+?)\s*</span>',
    caseSensitive: false,
  );

  /// Title in search cards. The site renders cards as
  /// `<span class="chapter-title-updated">Title</span>` inside the anchor.
  static final _reCardTitle = RegExp(
    r'<span[^>]*class="chapter-title-updated"[^>]*>([^<]+)</span>',
    caseSensitive: false,
  );

  static final _reTitle = RegExp(
    r'<h1[^>]*class="h1-title-manga[^"]*"[^>]*>(.*?)</h1>',
    caseSensitive: false,
    dotAll: true,
  );

  static final _reYear = RegExp(r'\((\d{4})\)\s*$');

  static final _reCover = RegExp(
    r'class="front-page-image"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"',
    caseSensitive: false,
  );

  static final _reType = RegExp(
    r'class="type-manga[^"]*"[^>]*>\s*([^<]+?)\s*</span>',
    caseSensitive: false,
  );

  static final _reSynopsis = RegExp(
    r'<p[^>]*class="content[^"]*"[^>]*>(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  );

  static final _reGenre = RegExp(
    r'<span[^>]*class="genre-entrada"[^>]*>([^<]+)</span>',
    caseSensitive: false,
  );

  /// Chapter list item — captures the reader URL.
  static final _reChapter = RegExp(
    r'<li[^>]*class="li-manga-chapter[^"]*"[^>]*>\s*'
    r'<a[^>]+href="([^"]+)"',
    caseSensitive: false,
    dotAll: true,
  );

  /// Reader image container.
  static final _reImageAlls = RegExp(
    r'<div[^>]+id="image-alls"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  );

  static final _reReaderImg = RegExp(
    r'<img[^>]+(?:data-src|src)="([^"]+)"',
    caseSensitive: false,
  );
}
