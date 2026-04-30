import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';

/// ManhwaWeb implementation of [MangaSourcePlugin].
///
/// JSON-native source — every contract method maps to a single REST
/// call on the backend host. The marketing host (`manhwaweb.com`) is
/// not contacted for data; we only target the backend API at
/// `manhwawebbackend-production.up.railway.app`.
///
/// [sourceMangaId] is the slug returned by the API
/// (`{title-slug}_{epoch}`). [sourceChapterId] is `{slug}-{chapter}`,
/// matching the path used by `/chapters/see/`.
final class ManhwaWebSourcePlugin implements MangaSourcePlugin {
  ManhwaWebSourcePlugin({http.Client? httpClient, MirrorList? mirrors})
    : _httpClient = httpClient ?? http.Client(),
      _rotator = MirrorRotator(mirrors ?? _defaultMirrors);

  static final MirrorList _defaultMirrors = MirrorList.single(
    Uri.parse('https://manhwawebbackend-production.up.railway.app/'),
  );

  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36';

  final http.Client _httpClient;
  final MirrorRotator _rotator;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.manhwaweb',
    displayName: 'ManhwaWeb',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>[
      'https://manhwaweb.com',
      'https://manhwawebbackend-production.up.railway.app',
    ],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        // ManhwaWeb only ships Spanish translations and aggregates
        // multiple uploader groups; we keep both flags true so the
        // picker UI surfaces the dimensions when relevant.
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
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        // The library endpoint requires the full filter set even when
        // most are blank — the controller doesn't tolerate missing
        // params and returns 500.
        final uri = base.replace(
          path: 'manhwa/library',
          queryParameters: <String, String>{
            'buscar': query.query,
            'estado': '',
            'tipo': '',
            'erotico': '',
            'demografia': '',
            'order_item': 'alfabetico',
            'order_dir': 'desc',
            // ManhwaWeb pages are 0-indexed.
            'page': '${(query.page - 1).clamp(0, 1 << 20)}',
            'generes': '',
          },
        );
        return _getJson(uri);
      });
    } catch (e) {
      return Failure(_transport('manhwaweb.search_transport_failed', e));
    }
    final data = json['data'];
    if (data is! List) {
      return Failure(
        _err(
          'manhwaweb.search_bad_envelope',
          'library response missing `data` array.',
        ),
      );
    }
    try {
      final matches = data
          .whereType<Map<String, Object?>>()
          .map(_parseMatch)
          .whereType<SourceMangaMatch>()
          .take(query.limit.clamp(1, 50))
          .toList(growable: false);
      return Success(matches);
    } catch (e) {
      return Failure(_err('manhwaweb.search_parse_failed', '$e'));
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
    if (id.isEmpty) {
      return Failure(
        _err('manhwaweb.detail_invalid_id', 'sourceMangaId must not be empty'),
      );
    }
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        return _getJson(base.resolve('manhwa/see/$id'));
      });
    } catch (e) {
      return Failure(_transport('manhwaweb.detail_transport_failed', e));
    }
    try {
      return Success(_parseDetail(json, sourceMangaId: id));
    } catch (e) {
      return Failure(_err('manhwaweb.detail_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapters

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    final id = query.sourceMangaId.trim();
    if (id.isEmpty) {
      return Failure(
        _err(
          'manhwaweb.chapters_invalid_id',
          'sourceMangaId must not be empty',
        ),
      );
    }
    // The detail endpoint already includes the chapter list — reuse it
    // rather than incurring a second round trip.
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        return _getJson(base.resolve('manhwa/see/$id'));
      });
    } catch (e) {
      return Failure(_transport('manhwaweb.chapters_transport_failed', e));
    }
    final raw = json['chapters'];
    if (raw is! List) return const Success(<SourceChapter>[]);
    try {
      final all = raw
          .whereType<Map<String, Object?>>()
          .map((row) => _parseChapter(row, sourceMangaId: id))
          .whereType<SourceChapter>()
          .toList();
      // Sort ascending by number to mirror the convention used by sibling
      // plugins. ManhwaWeb returns ascending order today but defending
      // against a future re-shuffle costs nothing.
      all.sort((a, b) => a.number.compareTo(b.number));
      if (query.scanlators.isEmpty) return Success(all);
      final allowed = query.scanlators.toSet();
      return Success(
        all
            .where((c) => c.scanlator != null && allowed.contains(c.scanlator))
            .toList(growable: false),
      );
    } catch (e) {
      return Failure(_err('manhwaweb.chapters_parse_failed', '$e'));
    }
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    final chId = chapter.sourceChapterId.trim();
    if (chId.isEmpty) {
      return Failure(
        _err('manhwaweb.pages_invalid_id', 'sourceChapterId must not be empty'),
      );
    }
    Map<String, Object?> json;
    try {
      json = await _rotator.run<Map<String, Object?>>((base) async {
        return _getJson(base.resolve('chapters/see/$chId'));
      });
    } catch (e) {
      return Failure(_transport('manhwaweb.pages_transport_failed', e));
    }
    final chObj = json['chapter'];
    if (chObj is! Map<String, Object?>) {
      return Failure(
        _err(
          'manhwaweb.pages_bad_envelope',
          'chapters/see response missing `chapter` object.',
        ),
      );
    }
    final imgs = chObj['img'];
    if (imgs is! List) {
      return Failure(
        _err(
          'manhwaweb.pages_empty',
          'chapter.img is missing or not a list for $chId.',
        ),
      );
    }
    final pages = <SourcePage>[];
    for (var i = 0; i < imgs.length; i++) {
      final raw = imgs[i];
      if (raw is! String || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      pages.add(SourcePage(index: i, imageUrl: uri));
    }
    if (pages.isEmpty) {
      return Failure(
        _err(
          'manhwaweb.pages_empty',
          'No usable image URLs in chapter.img for $chId.',
        ),
      );
    }
    return Success(pages);
  }

  // ---------------------------------------------------------------------------
  // helpers — http

  Future<Map<String, Object?>> _getJson(Uri uri) async {
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
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, Object?>) {
      throw FormatException(
        'Expected JSON object; got ${decoded.runtimeType} for $uri',
      );
    }
    return decoded;
  }

  // ---------------------------------------------------------------------------
  // helpers — parsing

  SourceMangaMatch? _parseMatch(Map<String, Object?> row) {
    final id = _readString(row['_id']) ?? _readString(row['real_id']);
    if (id == null) return null;
    final title =
        _readString(row['the_real_name']) ?? _readString(row['name_esp']);
    if (title == null) return null;
    final cover = _readString(row['_imagen']);
    return SourceMangaMatch(
      sourceId: id,
      title: title,
      thumbnailUrl: cover != null ? Uri.tryParse(cover) : null,
      format: _mapFormat(_readString(row['_tipo'])),
      country: MangaCountryOfOrigin.kr,
    );
  }

  SourceMangaDetail _parseDetail(
    Map<String, Object?> node, {
    required String sourceMangaId,
  }) {
    final title =
        _readString(node['the_real_name']) ??
        _readString(node['name_esp']) ??
        sourceMangaId;
    final synopsis = _readString(node['_sinopsis']);
    final cover = _readString(node['_imagen']);
    final genres = <String>[];
    final cats = node['_categoris'];
    if (cats is List) {
      for (final c in cats) {
        // Two shapes observed: a list of plain ints (search hit) and a
        // list of single-entry maps `{id: name}` (detail). The search
        // shape doesn't carry names, so we skip it here.
        if (c is Map) {
          for (final v in c.values) {
            if (v is String && v.isNotEmpty) genres.add(v);
          }
        }
      }
    }
    final groups = <String>[];
    final grupos = node['grupos'];
    if (grupos is List) {
      for (final g in grupos.whereType<Map>()) {
        final code = g['code'];
        if (code is Map) {
          final n = _readString(code['name']);
          if (n != null) groups.add(n.trim());
        }
      }
    }
    final extras = node['_extras'];
    final authors = <String>[];
    if (extras is Map) {
      final auts = extras['autores'];
      if (auts is List) {
        for (final a in auts) {
          if (a is String && a.isNotEmpty) authors.add(a);
        }
      }
    }
    return SourceMangaDetail(
      sourceId: sourceMangaId,
      title: title,
      synopsis: synopsis,
      thumbnailUrl: cover != null ? Uri.tryParse(cover) : null,
      tags: genres,
      authors: authors,
      artists:
          groups, // ManhwaWeb conflates uploader-groups into the same slot.
      status: _mapStatus(_readString(node['_status'])),
      format: _mapFormat(_readString(node['_tipo'])),
      country: MangaCountryOfOrigin.kr,
      originalLanguage: 'ko',
    );
  }

  SourceChapter? _parseChapter(
    Map<String, Object?> row, {
    required String sourceMangaId,
  }) {
    final numRaw = row['chapter'];
    final number = numRaw is num
        ? numRaw.toDouble()
        : double.tryParse('${numRaw ?? ''}');
    if (number == null) return null;
    // sourceChapterId mirrors the URL the reader endpoint uses:
    // `{slug}-{chapter}`. Numeric chapters are emitted as ints, fractional
    // as decimals — matching the on-wire convention.
    final friendly = number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
    final ts = row['create'];
    final published = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : null;
    return SourceChapter(
      sourceMangaId: sourceMangaId,
      sourceChapterId: '$sourceMangaId-$friendly',
      number: number,
      title: null,
      language: 'es',
      scanlator: 'ManhwaWeb',
      publishedAt: published,
    );
  }

  // ---------------------------------------------------------------------------
  // helpers — micro

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;

  static MangaStatus _mapStatus(String? raw) {
    if (raw == null) return MangaStatus.unknown;
    final v = raw.toLowerCase();
    if (v.contains('publica')) return MangaStatus.releasing;
    if (v.contains('finaliz') || v.contains('terminad')) {
      return MangaStatus.finished;
    }
    if (v.contains('hiatus') || v.contains('pausad')) return MangaStatus.hiatus;
    if (v.contains('cancelad')) return MangaStatus.cancelled;
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
