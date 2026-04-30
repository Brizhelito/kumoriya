import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';

/// LectorTMOo implementation of [MangaSourcePlugin].
///
/// LectorTMOo is a WordPress site running the `eastmanga` theme suite,
/// which exposes:
///
/// - Standard `wp/v2/manga` custom post type for series metadata, with
///   `_embed=wp:featuredmedia` to hydrate covers.
/// - Custom `/wp-json/eastmanga/v1/chapters?manga_id=…` endpoint that
///   returns the full chapter list keyed off the manga's WP post id —
///   the only reliable way to enumerate chapters since the relationship
///   is stored as post-meta and not a queryable filter.
/// - Standard `wp/v2/posts/{chapterId}` for chapter content. Page images
///   are inlined as `<img src="…">` tags in `content.rendered`.
///
/// `sourceMangaId` is the WP post id of the manga (numeric string).
/// `sourceChapterId` is the WP post id of the chapter post.
///
/// The sibling clone at `lectortmo.vip` exposes the same schema with
/// the `manganexus` theme; the S2.C URL override lets users target
/// either domain (or future domain rotations) without code changes.
final class LectorTmoSourcePlugin implements MangaSourcePlugin {
  LectorTmoSourcePlugin({http.Client? httpClient, MirrorList? mirrors})
    : _httpClient = httpClient ?? http.Client(),
      _rotator = MirrorRotator(mirrors ?? _defaultMirrors);

  static final MirrorList _defaultMirrors = MirrorList.single(
    Uri.parse('https://lectortmoo.com/'),
  );

  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  final http.Client _httpClient;
  final MirrorRotator _rotator;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.lectortmo',
    displayName: 'LectorTMOo',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://lectortmoo.com', 'https://lectortmo.vip'],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        // ES-only catalog. Scanlator data isn't structured on the
        // LectorTMOo side — every chapter is just attributed to the
        // site itself.
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
    List<dynamic> rows;
    try {
      rows = await _rotator.run<List<dynamic>>((base) async {
        final uri = base.replace(
          path: 'wp-json/wp/v2/manga',
          queryParameters: <String, String>{
            'search': query.query,
            'per_page': '${query.limit.clamp(1, 50)}',
            'page': '${query.page.clamp(1, 100)}',
            // Embed featured media so we get cover URLs in one round
            // trip; without this we'd need a second `/media/{id}` hit.
            '_embed': 'wp:featuredmedia',
            '_fields':
                'id,slug,title,content,featured_media,meta,_embedded,_links',
          },
        );
        return _getJsonArray(uri);
      });
    } catch (e) {
      return Failure(_transport('lectortmo.search_transport_failed', e));
    }
    try {
      final matches = rows
          .whereType<Map<String, Object?>>()
          .map(_parseMatch)
          .whereType<SourceMangaMatch>()
          .toList(growable: false);
      return Success(matches);
    } catch (e) {
      return Failure(_err('lectortmo.search_parse_failed', '$e'));
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
    final id = sourceMangaId.trim();
    if (id.isEmpty || int.tryParse(id) == null) {
      return Failure(
        _err(
          'lectortmo.detail_invalid_id',
          'sourceMangaId must be a numeric WP post id',
        ),
      );
    }
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        final uri = base.replace(
          path: 'wp-json/wp/v2/manga/$id',
          queryParameters: <String, String>{
            '_embed': 'wp:featuredmedia',
            '_fields':
                'id,slug,title,content,featured_media,meta,_embedded,_links',
          },
        );
        return _getJsonObject(uri);
      });
    } catch (e) {
      return Failure(_transport('lectortmo.detail_transport_failed', e));
    }
    try {
      return Success(_parseDetail(json, sourceMangaId: id));
    } catch (e) {
      return Failure(_err('lectortmo.detail_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapters

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    final id = query.sourceMangaId.trim();
    if (id.isEmpty || int.tryParse(id) == null) {
      return Failure(
        _err(
          'lectortmo.chapters_invalid_id',
          'sourceMangaId must be a numeric WP post id',
        ),
      );
    }
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        final uri = base.replace(
          path: 'wp-json/eastmanga/v1/chapters',
          queryParameters: <String, String>{'manga_id': id},
        );
        return _getJsonObject(uri);
      });
    } catch (e) {
      return Failure(_transport('lectortmo.chapters_transport_failed', e));
    }
    final raw = json['chapters'];
    if (raw is! List) return const Success(<SourceChapter>[]);
    try {
      final all = raw
          .whereType<Map<String, Object?>>()
          .map((row) => _parseChapter(row, sourceMangaId: id))
          .whereType<SourceChapter>()
          .toList();
      // Eastmanga returns chapters in unstable order — early ones in
      // ascending and recent ones in descending. Sort ascending so the
      // composite layer sees a monotonic series.
      all.sort((a, b) => a.number.compareTo(b.number));
      if (query.scanlators.isEmpty) return Success(all);
      final allowed = query.scanlators.toSet();
      return Success(
        all
            .where((c) => c.scanlator != null && allowed.contains(c.scanlator))
            .toList(growable: false),
      );
    } catch (e) {
      return Failure(_err('lectortmo.chapters_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    final chId = chapter.sourceChapterId.trim();
    if (chId.isEmpty || int.tryParse(chId) == null) {
      return Failure(
        _err(
          'lectortmo.pages_invalid_id',
          'sourceChapterId must be a numeric WP post id',
        ),
      );
    }
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        final uri = base.replace(
          path: 'wp-json/wp/v2/posts/$chId',
          queryParameters: <String, String>{
            '_fields': 'id,slug,title,date,content',
          },
        );
        return _getJsonObject(uri);
      });
    } catch (e) {
      return Failure(_transport('lectortmo.pages_transport_failed', e));
    }
    final content = (json['content'] as Map<String, Object?>?)?['rendered'];
    if (content is! String || content.isEmpty) {
      return Failure(
        _err(
          'lectortmo.pages_empty',
          'Chapter post $chId has no rendered content.',
        ),
      );
    }
    final urls = _extractImageUrls(content);
    if (urls.isEmpty) {
      return Failure(
        _err(
          'lectortmo.pages_empty',
          'No <img src="…"> tags found in chapter post $chId.',
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

  Future<Map<String, Object?>> _getJsonObject(Uri uri) async {
    final v = await _getJson(uri);
    if (v is! Map<String, Object?>) {
      throw FormatException(
        'Expected JSON object; got ${v.runtimeType} for $uri',
      );
    }
    return v;
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

  // ---------------------------------------------------------------------------
  // helpers — parsing

  SourceMangaMatch? _parseMatch(Map<String, Object?> row) {
    final id = _readInt(row['id']);
    if (id == null) return null;
    final title = _renderedString(row['title']);
    if (title == null || title.isEmpty) return null;
    final cover = _readEmbeddedCover(row);
    final meta = row['meta'];
    final type = meta is Map<String, Object?>
        ? _readString(meta['east_type'])
        : null;
    return SourceMangaMatch(
      sourceId: '$id',
      title: title,
      thumbnailUrl: cover,
      format: _mapFormat(type),
      country: MangaCountryOfOrigin.kr,
    );
  }

  SourceMangaDetail _parseDetail(
    Map<String, Object?> node, {
    required String sourceMangaId,
  }) {
    final title = _renderedString(node['title']) ?? sourceMangaId;
    final synopsis = _stripHtml(_renderedString(node['content']) ?? '');
    final cover = _readEmbeddedCover(node);
    final meta = node['meta'];
    String? type;
    String? status;
    String? author;
    String? artist;
    final aliases = <String>[];
    if (meta is Map<String, Object?>) {
      type = _readString(meta['east_type']);
      status = _readString(meta['east_status']);
      author = _readString(meta['east_author']);
      artist = _readString(meta['east_artist']);
      _addIfPresent(aliases, _readString(meta['east_synonyms']));
      _addIfPresent(aliases, _readString(meta['east_japanese']));
      _addIfPresent(aliases, _readString(meta['east_english']));
    }
    return SourceMangaDetail(
      sourceId: sourceMangaId,
      title: title,
      synopsis: synopsis.isEmpty ? null : synopsis,
      thumbnailUrl: cover,
      authors: <String>[if (author != null && author.isNotEmpty) author],
      artists: <String>[if (artist != null && artist.isNotEmpty) artist],
      tags: const <String>[],
      status: _mapStatus(status),
      format: _mapFormat(type),
      country: MangaCountryOfOrigin.kr,
      originalLanguage: 'ko',
    );
  }

  SourceChapter? _parseChapter(
    Map<String, Object?> row, {
    required String sourceMangaId,
  }) {
    final id = _readInt(row['id']);
    if (id == null) return null;
    final status = _readString(row['status']);
    if (status != null && status != 'publish') return null;
    final number = _parseChapterNumber(row);
    if (number == null) return null;
    return SourceChapter(
      sourceMangaId: sourceMangaId,
      sourceChapterId: '$id',
      number: number,
      title: _readString(row['title']),
      language: 'es',
      scanlator: 'LectorTMOo',
    );
  }

  /// Extracts page image URLs from a chapter post's `content.rendered`.
  ///
  /// LectorTMOo emits one `<img>` per page interleaved with `<br />`
  /// tags. We rely on document order to preserve page order.
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
        if (m.group(1) != null) m.group(1)!,
    ];
  }

  // ---------------------------------------------------------------------------
  // helpers — micro

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static int? _readInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String? _renderedString(Object? v) {
    if (v is Map) {
      final r = v['rendered'];
      if (r is String) return _decodeEntities(r);
    }
    if (v is String) return _decodeEntities(v);
    return null;
  }

  /// Reads `_embedded.wp:featuredmedia[0].source_url`. WP REST returns
  /// the curie key literally as `wp:featuredmedia`.
  Uri? _readEmbeddedCover(Map<String, Object?> node) {
    final embedded = node['_embedded'];
    if (embedded is! Map<String, Object?>) return null;
    final media = embedded['wp:featuredmedia'];
    if (media is! List || media.isEmpty) return null;
    final first = media.first;
    if (first is! Map<String, Object?>) return null;
    final url = _readString(first['source_url']);
    return url == null ? null : Uri.tryParse(url);
  }

  /// Parses the chapter number from either the `chapter` field (string
  /// or number) or — if empty — from the localized title
  /// (`"Unordinary Capítulo 34"`).
  static double? _parseChapterNumber(Map<String, Object?> row) {
    final raw = row['chapter'];
    if (raw is num) return raw.toDouble();
    if (raw is String && raw.isNotEmpty) {
      final n = double.tryParse(raw);
      if (n != null) return n;
    }
    final title = row['title'];
    if (title is String) {
      final m = RegExp(
        r'(?:Cap[ií]tulo|Chapter|Cap)\s+(\d+(?:\.\d+)?)',
      ).firstMatch(title);
      if (m != null) return double.tryParse(m.group(1)!);
    }
    return null;
  }

  static void _addIfPresent(List<String> sink, String? v) {
    if (v != null && v.trim().isNotEmpty) sink.add(v.trim());
  }

  static String _stripHtml(String s) => _decodeEntities(
    s.replaceAll(RegExp(r'<[^>]+>'), ' '),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _decodeEntities(String s) => s
      .replaceAll('&#8217;', '\u2019')
      .replaceAll('&#8220;', '\u201c')
      .replaceAll('&#8221;', '\u201d')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', '\'');

  static MangaStatus _mapStatus(String? raw) {
    if (raw == null) return MangaStatus.unknown;
    final v = raw.toLowerCase();
    if (v == 'ongoing' || v.contains('publica')) return MangaStatus.releasing;
    if (v == 'completed' || v.contains('finaliz')) {
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
