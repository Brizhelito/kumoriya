import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';

import 'internal/nuxt_data_decoder.dart';

/// Olympus Scanlation implementation of [MangaSourcePlugin].
///
/// Olympus is a LatAm scanlator running a Nuxt 3 SSR frontend backed by a
/// JSON API on a paired `dashboard.*` subdomain. Each "mirror" is the
/// pair (web frontend, dashboard API). The plugin owns two
/// [MirrorRotator]s so transport-level failures on either layer fall
/// through to the next pair without exposing rotation upstream.
///
/// Read [README.md] for the discovered endpoint surface. Coverage:
///
/// - `search`: in-memory filter over the cached `/api/series/list`
///   response. Olympus does not expose a server-side search endpoint
///   without auth; the catalog is small (~840 entries) and barely
///   churns, so client-side ranking is fine.
/// - `getLatestUpdates`: returns an empty success. The `/capitulos`
///   page is server-rendered and would require Nuxt-data scraping; the
///   plugin contract explicitly allows an empty response when a source
///   has no clean latest feed.
/// - `getMangaDetail`: scrapes `__NUXT_DATA__` from the public detail
///   page (the JSON API for detail requires auth).
/// - `getChapters`: paginated `dashboard/api/series/{slug}/chapters`.
/// - `getChapterPages`: scrapes `__NUXT_DATA__` from the public reader
///   page.
final class OlympusSourcePlugin implements MangaSourcePlugin {
  /// Builds the plugin.
  ///
  /// [webMirrors] / [dashboardMirrors] override the default mirror
  /// pairs (mostly for tests). When omitted, the plugin uses the three
  /// known live pairs.
  ///
  /// [catalogTtl] controls how long the in-memory `/api/series/list`
  /// cache is reused between `search` calls. Default 1 hour — the
  /// catalog only changes when Olympus adds a brand-new series, which
  /// is at most a few times per day.
  OlympusSourcePlugin({
    http.Client? httpClient,
    MirrorList? webMirrors,
    MirrorList? dashboardMirrors,
    Duration catalogTtl = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : _httpClient = httpClient ?? http.Client(),
       _webRotator = MirrorRotator(webMirrors ?? _defaultWebMirrors),
       _dashboardRotator = MirrorRotator(
         dashboardMirrors ?? _defaultDashboardMirrors,
       ),
       _catalogTtl = catalogTtl,
       _clock = clock ?? DateTime.now;

  static final MirrorList _defaultWebMirrors = MirrorList(<Uri>[
    Uri.parse('https://olympusbiblioteca.com/'),
    Uri.parse('https://olympusscanlation.com/'),
    Uri.parse('https://tomanhua.com/'),
  ]);

  static final MirrorList _defaultDashboardMirrors = MirrorList(<Uri>[
    Uri.parse('https://dashboard.olympusbiblioteca.com/'),
    Uri.parse('https://dashboard.olympusscanlation.com/'),
    Uri.parse('https://dashboard.tomanhua.com/'),
  ]);

  // Realistic UA — recon notes mention a light Cloudflare challenge that
  // is bypassed transparently with a normal browser UA. Anything that
  // identifies Kumoriya gets challenged.
  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  final http.Client _httpClient;
  final MirrorRotator _webRotator;
  final MirrorRotator _dashboardRotator;
  final Duration _catalogTtl;
  final DateTime Function() _clock;

  // ----- catalog cache ------------------------------------------------
  List<_CatalogEntry>? _catalog;
  DateTime? _catalogFetchedAt;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.olympus',
    displayName: 'Olympus Scanlation',
    type: PluginType.source,
    iconUrl:
        'https://dashboard.olympusbiblioteca.com/storage/teams/originals/logo5.png',
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>[
      'https://olympusbiblioteca.com',
      'https://olympusscanlation.com',
      'https://tomanhua.com',
    ],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        // Olympus only ships Spanish translations; language filter is a
        // no-op but the contract field stays true so the UI doesn't
        // misrepresent it as language-blind.
        supportsLanguageFilter: true,
        // Single in-house team ("Olympus") on every chapter; scanlator
        // filtering is degenerate but still honored when requested.
        supportsScanlatorFilter: true,
        // No clean latest-feed endpoint. See class doc.
        supportsLatestFeed: false,
        // Pages are direct CDN URLs on `dashboard.*` and don't require
        // a Referer or signed token to load.
        requiresPageHeaders: false,
      );

  // ---------------------------------------------------------------------------
  // search

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  ) async {
    final catalog = await _ensureCatalog();
    return catalog.fold(
      onFailure: Failure.new,
      onSuccess: (entries) {
        final needle = _normalize(query.query);
        if (needle.isEmpty) {
          // Empty query => return the catalog head so the UI has
          // something to render. Cap to limit so we don't shovel 800+.
          final head = entries.take(query.limit.clamp(1, 50)).toList();
          return Success(head.map(_entryToMatch).toList(growable: false));
        }
        final matches = entries.where(
          (e) => _normalize(e.name).contains(needle),
        );
        // Pagination is client-side: skip = (page-1)*limit.
        final offset = (query.page - 1) * query.limit;
        final paged = matches
            .skip(offset)
            .take(query.limit.clamp(1, 50))
            .toList(growable: false);
        return Success(paged.map(_entryToMatch).toList(growable: false));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // latest updates

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> getLatestUpdates({
    int page = 1,
    int limit = 20,
  }) async {
    // No clean unauthenticated feed endpoint. Per contract: surface as
    // empty success rather than failure so the composite repo doesn't
    // surface an error to the UI when the user is just browsing latest
    // chapters across sources.
    return const Success(<SourceMangaMatch>[]);
  }

  // ---------------------------------------------------------------------------
  // manga detail

  @override
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  ) async {
    if (sourceMangaId.isEmpty) {
      return Failure(
        _err('olympus.detail_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    String body;
    try {
      body = await _webRotator.run<String>((base) async {
        final uri = base.resolve('series/comic-$sourceMangaId');
        return _getString(uri);
      });
    } catch (e) {
      return Failure(_transport('olympus.detail_transport_failed', e));
    }

    final root = NuxtDataDecoder.extractFromHtml(body);
    if (root is! Map<String, Object?>) {
      return Failure(
        _err(
          'olympus.detail_no_nuxt_data',
          'Detail page did not contain a parseable __NUXT_DATA__ block.',
        ),
      );
    }
    final data = _readDetailNode(root);
    if (data == null) {
      return Failure(
        _err(
          'olympus.detail_not_found',
          'Detail payload missing for sourceMangaId=$sourceMangaId',
        ),
      );
    }

    try {
      return Success(_parseDetail(data));
    } catch (e) {
      return Failure(_err('olympus.detail_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapters

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    final pageNum = query.page.clamp(1, 1 << 20);
    Map<String, Object?> json;
    try {
      json = await _dashboardRotator.run<Map<String, Object?>>((base) async {
        final uri = base.resolve(
          'api/series/${query.sourceMangaId}/chapters'
          '?page=$pageNum&direction=desc&type=comic',
        );
        return _getJson(uri);
      });
    } catch (e) {
      return Failure(_transport('olympus.chapters_transport_failed', e));
    }

    final data = json['data'];
    if (data is! List) {
      return Failure(
        _err(
          'olympus.chapters_bad_envelope',
          'Expected `data` to be a list; got ${data.runtimeType}',
        ),
      );
    }

    try {
      final all = data
          .whereType<Map<String, Object?>>()
          .map((row) => _parseChapter(row, sourceMangaId: query.sourceMangaId))
          .whereType<SourceChapter>()
          .toList();

      if (query.scanlators.isEmpty) {
        return Success(all);
      }
      final allowed = query.scanlators.toSet();
      final filtered = all
          .where((c) => c.scanlator != null && allowed.contains(c.scanlator))
          .toList(growable: false);
      return Success(filtered);
    } catch (e) {
      return Failure(_err('olympus.chapters_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    String body;
    try {
      body = await _webRotator.run<String>((base) async {
        final uri = base.resolve(
          'capitulo/${chapter.sourceChapterId}/comic-${chapter.sourceMangaId}',
        );
        return _getString(uri);
      });
    } catch (e) {
      return Failure(_transport('olympus.pages_transport_failed', e));
    }

    final root = NuxtDataDecoder.extractFromHtml(body);
    final pages = _extractPages(root);
    if (pages.isEmpty) {
      return Failure(
        _err(
          'olympus.pages_empty',
          'Reader page did not expose a non-empty pages array '
              'for chapter ${chapter.sourceChapterId}.',
        ),
      );
    }
    return Success(<SourcePage>[
      for (var i = 0; i < pages.length; i++)
        SourcePage(index: i, imageUrl: Uri.parse(pages[i])),
    ]);
  }

  // ---------------------------------------------------------------------------
  // catalog

  Future<Result<List<_CatalogEntry>, KumoriyaError>> _ensureCatalog() async {
    final cached = _catalog;
    final fetchedAt = _catalogFetchedAt;
    if (cached != null &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < _catalogTtl) {
      return Success(cached);
    }
    Map<String, Object?> json;
    try {
      json = await _webRotator.run<Map<String, Object?>>((base) async {
        return _getJson(base.resolve('api/series/list'));
      });
    } catch (e) {
      return Failure(_transport('olympus.catalog_transport_failed', e));
    }
    final data = json['data'];
    if (data is! List) {
      return Failure(
        _err(
          'olympus.catalog_bad_envelope',
          'Expected `data` to be a list; got ${data.runtimeType}',
        ),
      );
    }
    final entries = <_CatalogEntry>[];
    for (final row in data.whereType<Map<String, Object?>>()) {
      // Filter to comics only — novelas are out of scope for the manga
      // plugin and would muddy match results.
      if (row['type'] != 'comic') continue;
      final slug = _readString(row['slug']);
      final name = _readString(row['name']);
      if (slug == null || name == null) continue;
      entries.add(
        _CatalogEntry(
          id: row['id'] is int ? row['id'] as int : null,
          slug: slug,
          name: name,
          cover: _readString(row['cover']),
        ),
      );
    }
    _catalog = entries;
    _catalogFetchedAt = _clock();
    return Success(entries);
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

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final body = await _getString(uri);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw FormatException(
        'Expected JSON object; got ${decoded.runtimeType} for $uri',
      );
    }
    return decoded;
  }

  // ---------------------------------------------------------------------------
  // helpers — parsing

  SourceMangaMatch _entryToMatch(_CatalogEntry e) => SourceMangaMatch(
    sourceId: e.slug,
    title: e.name,
    thumbnailUrl: e.cover != null ? Uri.tryParse(e.cover!) : null,
    format: MangaFormat.unknown,
    country: MangaCountryOfOrigin.kr,
  );

  /// Walks the decoded `__NUXT_DATA__` root and finds the manga detail
  /// payload. The root has shape:
  /// `{"data": {"<some-route-key>": {"data": <detail>}}}`.
  Map<String, Object?>? _readDetailNode(Map<String, Object?> root) {
    final outer = root['data'];
    if (outer is! Map<String, Object?>) return null;
    for (final value in outer.values) {
      if (value is Map<String, Object?>) {
        final inner = value['data'];
        if (inner is Map<String, Object?> &&
            inner.containsKey('id') &&
            inner.containsKey('name') &&
            inner.containsKey('slug')) {
          return inner;
        }
      }
    }
    return null;
  }

  SourceMangaDetail _parseDetail(Map<String, Object?> node) {
    final id = _readString(node['slug']) ?? '';
    final title = _readString(node['name']) ?? id;
    final summary = _readString(node['summary']);
    final cover = _readString(node['cover']);
    final genres = <String>[];
    final rawGenres = node['genres'];
    if (rawGenres is List) {
      for (final g in rawGenres.whereType<Map<String, Object?>>()) {
        final n = _readString(g['name']);
        if (n != null) genres.add(n.trim());
      }
    }
    final teamName = _readString(
      (node['team'] as Map<String, Object?>?)?['name'],
    )?.trim();
    // `status` is an object `{id, name}` on Olympus — pluck the name.
    final statusRaw = _readString(
      (node['status'] as Map<String, Object?>?)?['name'],
    );
    return SourceMangaDetail(
      sourceId: id,
      title: title.trim(),
      synopsis: summary,
      thumbnailUrl: cover != null ? Uri.tryParse(cover) : null,
      tags: genres,
      authors: const <String>[],
      artists: teamName != null ? <String>[teamName] : const <String>[],
      status: _mapStatus(statusRaw),
      format: MangaFormat.manhwa,
      country: MangaCountryOfOrigin.kr,
      originalLanguage: 'ko',
    );
  }

  SourceChapter? _parseChapter(
    Map<String, Object?> row, {
    required String sourceMangaId,
  }) {
    final idRaw = row['id'];
    if (idRaw is! int) return null;
    final name = _readString(row['name']);
    final number = name == null ? null : double.tryParse(name);
    if (number == null) {
      // Skip chapters with non-parseable numbers (e.g. bonus content)
      // for now — the contract requires `number` to be set.
      return null;
    }
    final teamName = _readString(
      (row['team'] as Map<String, Object?>?)?['name'],
    )?.trim();
    final publishedAt = _parseIso(_readString(row['published_at']));
    return SourceChapter(
      sourceMangaId: sourceMangaId,
      sourceChapterId: '$idRaw',
      number: number,
      title: null,
      language: 'es',
      scanlator: teamName,
      publishedAt: publishedAt,
    );
  }

  /// Walks the decoded `__NUXT_DATA__` root from a chapter reader page
  /// and returns the ordered pages array (URL strings).
  List<String> _extractPages(Object? root) {
    if (root is! Map<String, Object?>) return const <String>[];
    final outer = root['data'];
    if (outer is! Map<String, Object?>) return const <String>[];
    for (final value in outer.values) {
      if (value is Map<String, Object?>) {
        final chapter = value['chapter'];
        if (chapter is Map<String, Object?>) {
          final pages = chapter['pages'];
          if (pages is List) {
            return pages.whereType<String>().toList(growable: false);
          }
        }
      }
    }
    return const <String>[];
  }

  // ---------------------------------------------------------------------------
  // helpers — micro

  static String _normalize(String s) => s.trim().toLowerCase();

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static DateTime? _parseIso(String? v) {
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  static MangaStatus _mapStatus(String? raw) {
    if (raw == null) return MangaStatus.unknown;
    final v = raw.trim().toLowerCase();
    if (v.startsWith('activo')) return MangaStatus.releasing;
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

/// Plain-data row from the `/api/series/list` response, kept narrow on
/// purpose so the catalog cache stays cheap to retain.
final class _CatalogEntry {
  const _CatalogEntry({
    required this.id,
    required this.slug,
    required this.name,
    required this.cover,
  });

  final int? id;
  final String slug;
  final String name;
  final String? cover;
}
