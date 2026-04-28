import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

/// MangaDex (`https://api.mangadex.org`) implementation of
/// [MangaSourcePlugin].
///
/// MangaDex exposes a JSON REST API and a token-issuing image host
/// network ("MD\@Home"). This plugin maps each contract method to a
/// single primary endpoint:
///
/// - [search]: `GET /manga?title=…`
/// - [getLatestUpdates]: `GET /manga?order[latestUploadedChapter]=desc`
/// - [getMangaDetail]: `GET /manga/{id}` with cover/author/artist
///   includes.
/// - [getChapters]: `GET /manga/{id}/feed` with `translatedLanguage[]`
///   and `includes[]=scanlation_group`.
/// - [getChapterPages]: `GET /at-home/server/{chapterId}` →
///   `{baseUrl}/data/{hash}/{filename}`.
///
/// All MangaDex IDs are RFC-4122 UUIDs and are used verbatim as
/// `sourceMangaId` / `sourceChapterId`.
final class MangaDexSourcePlugin implements MangaSourcePlugin {
  MangaDexSourcePlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://api.mangadex.org/');

  final http.Client _httpClient;
  final Uri _baseUri;

  static const _userAgent = 'Kumoriya/0.1 (+https://github.com/Brizhelito)';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.mangadex',
    displayName: 'MangaDex',
    type: PluginType.source,
    iconUrl: 'https://mangadex.org/img/brand/mangadex-logo.svg',
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://mangadex.org', 'https://api.mangadex.org'],
  );

  @override
  MangaSourceCapabilities get mangaCapabilities =>
      const MangaSourceCapabilities(
        supportsLanguageFilter: true,
        supportsScanlatorFilter: true,
        supportsLatestFeed: true,
        requiresPageHeaders: false,
      );

  // ---------------------------------------------------------------------------
  // search

  @override
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  ) async {
    final params = <String, List<String>>{
      'title': [query.query],
      'limit': [query.limit.clamp(1, 100).toString()],
      'offset': [_offsetFor(query.page, query.limit).toString()],
      'includes[]': ['cover_art'],
      'contentRating[]': const ['safe', 'suggestive', 'erotica'],
    };
    if (query.languages.isNotEmpty) {
      params['availableTranslatedLanguage[]'] = query.languages;
    }

    final res = await _getJson('manga', params);
    return res.fold(
      onFailure: Failure.new,
      onSuccess: (json) {
        try {
          final data = (json['data'] as List<dynamic>?) ?? const <dynamic>[];
          final matches = data
              .whereType<Map<String, dynamic>>()
              .map(_parseMangaMatch)
              .toList(growable: false);
          return Success(matches);
        } catch (e) {
          return Failure(_mapping('mangadex.search_parse_failed', e));
        }
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
    assert(page >= 1, 'page must be 1-indexed');
    assert(limit > 0, 'limit must be positive');

    final params = <String, List<String>>{
      'limit': [limit.clamp(1, 100).toString()],
      'offset': [_offsetFor(page, limit).toString()],
      'includes[]': ['cover_art'],
      'order[latestUploadedChapter]': const ['desc'],
      'hasAvailableChapters': const ['true'],
      'contentRating[]': const ['safe', 'suggestive', 'erotica'],
    };

    final res = await _getJson('manga', params);
    return res.fold(
      onFailure: Failure.new,
      onSuccess: (json) {
        try {
          final data = (json['data'] as List<dynamic>?) ?? const <dynamic>[];
          final matches = data
              .whereType<Map<String, dynamic>>()
              .map(_parseMangaMatch)
              .toList(growable: false);
          return Success(matches);
        } catch (e) {
          return Failure(_mapping('mangadex.latest_parse_failed', e));
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // manga detail

  @override
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  ) async {
    if (sourceMangaId.isEmpty) {
      return Failure(
        _mapping(
          'mangadex.detail_invalid_id',
          'sourceMangaId must not be empty',
        ),
      );
    }

    final res = await _getJson('manga/$sourceMangaId', const {
      'includes[]': ['cover_art', 'author', 'artist'],
    });

    return res.fold(
      onFailure: Failure.new,
      onSuccess: (json) {
        try {
          final data = json['data'] as Map<String, dynamic>?;
          if (data == null) {
            return Failure(
              SimpleError(
                code: 'mangadex.detail_not_found',
                message: 'No data block in detail response for $sourceMangaId',
                kind: KumoriyaErrorKind.notFound,
              ),
            );
          }
          return Success(_parseMangaDetail(data));
        } catch (e) {
          return Failure(_mapping('mangadex.detail_parse_failed', e));
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // chapters

  @override
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  ) async {
    final params = <String, List<String>>{
      'limit': [query.limit.clamp(1, 500).toString()],
      'offset': [_offsetFor(query.page, query.limit).toString()],
      'includes[]': ['scanlation_group'],
      'order[volume]': const ['asc'],
      'order[chapter]': const ['asc'],
      'contentRating[]': const ['safe', 'suggestive', 'erotica'],
    };
    if (query.languages.isNotEmpty) {
      params['translatedLanguage[]'] = query.languages;
    }

    final res = await _getJson('manga/${query.sourceMangaId}/feed', params);
    return res.fold(
      onFailure: Failure.new,
      onSuccess: (json) {
        try {
          final data = (json['data'] as List<dynamic>?) ?? const <dynamic>[];
          final all = data
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => _parseChapter(row, sourceMangaId: query.sourceMangaId),
              )
              .whereType<SourceChapter>()
              .toList();

          if (query.scanlators.isEmpty) {
            return Success(all);
          }
          final allowed = query.scanlators.toSet();
          final filtered = all
              .where(
                (c) => c.scanlator != null && allowed.contains(c.scanlator),
              )
              .toList(growable: false);
          return Success(filtered);
        } catch (e) {
          return Failure(_mapping('mangadex.chapters_parse_failed', e));
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // chapter pages

  @override
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  ) async {
    final res = await _getJson(
      'at-home/server/${chapter.sourceChapterId}',
      const <String, List<String>>{},
    );
    return res.fold(
      onFailure: Failure.new,
      onSuccess: (json) {
        try {
          final baseUrlRaw = json['baseUrl'] as String?;
          final ch = json['chapter'] as Map<String, dynamic>?;
          final hash = ch?['hash'] as String?;
          final files = (ch?['data'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false);

          if (baseUrlRaw == null ||
              hash == null ||
              files == null ||
              files.isEmpty) {
            return Failure(
              SimpleError(
                code: 'mangadex.pages_empty',
                message:
                    'MD@Home response missing baseUrl/hash/data for '
                    'chapter "${chapter.sourceChapterId}"',
                kind: KumoriyaErrorKind.unexpected,
              ),
            );
          }

          final base = Uri.parse(baseUrlRaw);
          final pages = <SourcePage>[];
          for (var i = 0; i < files.length; i++) {
            final filename = files[i];
            final url = base.replace(
              pathSegments: <String>[
                ...base.pathSegments.where((s) => s.isNotEmpty),
                'data',
                hash,
                filename,
              ],
            );
            pages.add(SourcePage(index: i, imageUrl: url));
          }
          return Success(pages);
        } catch (e) {
          return Failure(_mapping('mangadex.pages_parse_failed', e));
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // helpers

  Future<Result<Map<String, dynamic>, KumoriyaError>> _getJson(
    String path,
    Map<String, List<String>> params,
  ) async {
    final uri = _buildUri(path, params);
    http.Response response;
    try {
      response = await _httpClient.get(
        uri,
        headers: const {'Accept': 'application/json', 'User-Agent': _userAgent},
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'mangadex.transport_failed',
          message: 'GET $uri failed: $e',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    if (response.statusCode == 404) {
      return Failure(
        SimpleError(
          code: 'mangadex.not_found',
          message: 'GET $uri returned 404',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        SimpleError(
          code: 'mangadex.bad_status',
          message: 'GET $uri returned ${response.statusCode}',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return Failure(
          _mapping(
            'mangadex.bad_envelope',
            'expected JSON object, got ${decoded.runtimeType}',
          ),
        );
      }
      final result = decoded['result'];
      if (result is String && result != 'ok') {
        return Failure(
          _mapping(
            'mangadex.api_error',
            'MangaDex returned result="$result" for $uri',
          ),
        );
      }
      return Success(decoded);
    } catch (e) {
      return Failure(_mapping('mangadex.bad_json', e));
    }
  }

  Uri _buildUri(String path, Map<String, List<String>> params) {
    final base = _baseUri;
    final basePath = base.path.isEmpty
        ? ''
        : (base.path.endsWith('/')
              ? base.path.substring(0, base.path.length - 1)
              : base.path);
    final fullPath = '$basePath/$path';
    if (params.isEmpty) {
      return base.replace(path: fullPath);
    }
    return base.replace(
      path: fullPath,
      queryParameters: <String, dynamic>{
        for (final entry in params.entries) entry.key: entry.value,
      },
    );
  }

  static int _offsetFor(int page, int limit) => (page - 1) * limit;

  KumoriyaError _mapping(String code, Object detail) => SimpleError(
    code: code,
    message: detail.toString(),
    kind: KumoriyaErrorKind.mapping,
  );

  // ---------------------------------------------------------------------------
  // parsers

  SourceMangaMatch _parseMangaMatch(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final attributes =
        (row['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final relationships =
        (row['relationships'] as List<dynamic>?) ?? const <dynamic>[];

    final titles = _readLocalizedList(attributes['title']);
    final altTitles = _readAltTitles(attributes['altTitles']);
    final primary = titles.isNotEmpty
        ? titles.first
        : (altTitles.isNotEmpty ? altTitles.first : id);
    final aliases = <String>[...titles.skip(1), ...altTitles];

    final coverFileName = _findRelationshipAttr(
      relationships,
      type: 'cover_art',
      key: 'fileName',
    );
    final thumb = coverFileName != null
        ? Uri.parse(
            'https://uploads.mangadex.org/covers/$id/$coverFileName.256.jpg',
          )
        : null;

    return SourceMangaMatch(
      sourceId: id,
      title: primary,
      aliases: aliases.where((a) => a.isNotEmpty).toList(growable: false),
      thumbnailUrl: thumb,
      releaseYear: _readInt(attributes['year']),
      format: _parseFormat(attributes),
      country: _parseCountry(attributes['originalLanguage']),
      externalIds: _parseExternalIds(attributes['links']),
    );
  }

  /// Extract cross-database links from the MangaDex `attributes.links`
  /// map. Only string values are kept; non-string entries are ignored
  /// defensively (MangaDex has historically returned arrays / nulls
  /// for some entries on partial records).
  Map<String, String> _parseExternalIds(Object? raw) {
    if (raw is! Map<String, dynamic>) return const <String, String>{};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (value is String && value.isNotEmpty) {
        out[key] = value;
      }
    });
    return Map<String, String>.unmodifiable(out);
  }

  SourceMangaDetail _parseMangaDetail(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final attributes =
        (row['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final relationships =
        (row['relationships'] as List<dynamic>?) ?? const <dynamic>[];

    final titles = _readLocalizedList(attributes['title']);
    final altTitles = _readAltTitles(attributes['altTitles']);
    final primary = titles.isNotEmpty
        ? titles.first
        : (altTitles.isNotEmpty ? altTitles.first : id);
    final aliases = <String>[
      ...titles.skip(1),
      ...altTitles,
    ].where((a) => a.isNotEmpty).toList(growable: false);

    final synopsis = _pickPreferredString(
      attributes['description'],
      preferred: const ['en'],
    );

    final authors = _collectRelationshipNames(relationships, type: 'author');
    final artists = _collectRelationshipNames(relationships, type: 'artist');

    final tags = _readTags(attributes['tags']);

    final coverFileName = _findRelationshipAttr(
      relationships,
      type: 'cover_art',
      key: 'fileName',
    );
    final thumb = coverFileName != null
        ? Uri.parse('https://uploads.mangadex.org/covers/$id/$coverFileName')
        : null;

    return SourceMangaDetail(
      sourceId: id,
      title: primary,
      synopsis: synopsis,
      aliases: aliases,
      authors: authors,
      artists: artists,
      tags: tags,
      thumbnailUrl: thumb,
      releaseYear: _readInt(attributes['year']),
      status: _parseStatus(attributes['status']),
      format: _parseFormat(attributes),
      country: _parseCountry(attributes['originalLanguage']),
      originalLanguage: _readString(attributes['originalLanguage']),
    );
  }

  SourceChapter? _parseChapter(
    Map<String, dynamic> row, {
    required String sourceMangaId,
  }) {
    final id = row['id'] as String?;
    if (id == null) return null;
    final attributes =
        (row['attributes'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final relationships =
        (row['relationships'] as List<dynamic>?) ?? const <dynamic>[];

    final number = _parseDouble(attributes['chapter']);
    if (number == null) {
      // Skip chapters MangaDex returns with `null` chapter numbers
      // (e.g. unnumbered prologues). They can't be ordered by number
      // so they're filtered out for now.
      return null;
    }

    final volume = _parseInt(attributes['volume']);
    final language = _readString(attributes['translatedLanguage']) ?? 'en';
    final pageCount = _readInt(attributes['pages']);
    final publishedAt = _parseIsoDate(attributes['publishAt']);
    final scanlator = _findRelationshipAttr(
      relationships,
      type: 'scanlation_group',
      key: 'name',
    );

    return SourceChapter(
      sourceMangaId: sourceMangaId,
      sourceChapterId: id,
      number: number,
      title: _readString(attributes['title']),
      volume: volume,
      language: language,
      scanlator: scanlator,
      publishedAt: publishedAt,
      pageCount: pageCount,
    );
  }

  // ---------------------------------------------------------------------------
  // micro-parsers

  static List<String> _readLocalizedList(Object? raw) {
    if (raw is! Map) return const <String>[];
    return raw.values.whereType<String>().toList(growable: false);
  }

  static List<String> _readAltTitles(Object? raw) {
    if (raw is! List) return const <String>[];
    final out = <String>[];
    for (final entry in raw) {
      if (entry is Map) {
        for (final v in entry.values) {
          if (v is String && v.isNotEmpty) out.add(v);
        }
      }
    }
    return out;
  }

  static String? _pickPreferredString(
    Object? raw, {
    required List<String> preferred,
  }) {
    if (raw is! Map) return null;
    for (final lang in preferred) {
      final v = raw[lang];
      if (v is String && v.isNotEmpty) return v;
    }
    for (final v in raw.values) {
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static List<String> _readTags(Object? raw) {
    if (raw is! List) return const <String>[];
    final out = <String>[];
    for (final entry in raw) {
      if (entry is Map) {
        final attrs = entry['attributes'];
        if (attrs is Map) {
          final name = _pickPreferredString(
            attrs['name'],
            preferred: const ['en'],
          );
          if (name != null) out.add(name);
        }
      }
    }
    return out;
  }

  static String? _findRelationshipAttr(
    List<dynamic> relationships, {
    required String type,
    required String key,
  }) {
    for (final r in relationships) {
      if (r is Map &&
          r['type'] == type &&
          r['attributes'] is Map<String, dynamic>) {
        final attrs = r['attributes'] as Map<String, dynamic>;
        final v = attrs[key];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  static List<String> _collectRelationshipNames(
    List<dynamic> relationships, {
    required String type,
  }) {
    final out = <String>[];
    for (final r in relationships) {
      if (r is Map && r['type'] == type) {
        final attrs = r['attributes'];
        if (attrs is Map) {
          final name = attrs['name'];
          if (name is String && name.isNotEmpty) out.add(name);
        }
      }
    }
    return out;
  }

  static String? _readString(Object? v) =>
      v is String && v.isNotEmpty ? v : null;
  static int? _readInt(Object? v) => v is int ? v : null;
  static int? _parseInt(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _parseDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _parseIsoDate(Object? v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  static MangaStatus _parseStatus(Object? raw) {
    if (raw is! String) return MangaStatus.unknown;
    switch (raw) {
      case 'ongoing':
        return MangaStatus.releasing;
      case 'completed':
        return MangaStatus.finished;
      case 'hiatus':
        return MangaStatus.hiatus;
      case 'cancelled':
        return MangaStatus.cancelled;
      default:
        return MangaStatus.unknown;
    }
  }

  static MangaFormat _parseFormat(Map<String, dynamic> attributes) {
    final tags = attributes['tags'];
    final country = _readString(attributes['originalLanguage']);
    if (tags is List) {
      for (final t in tags) {
        if (t is Map) {
          final attrs = t['attributes'];
          if (attrs is Map) {
            final name = _pickPreferredString(
              attrs['name'],
              preferred: const ['en'],
            );
            if (name == null) continue;
            switch (name.toLowerCase()) {
              case 'oneshot':
                return MangaFormat.oneShot;
              case 'doujinshi':
                return MangaFormat.doujinshi;
              case 'long strip':
              case 'web comic':
                return _formatFromCountry(country);
            }
          }
        }
      }
    }
    return _formatFromCountry(country);
  }

  static MangaFormat _formatFromCountry(String? country) {
    switch (country) {
      case 'ko':
        return MangaFormat.manhwa;
      case 'zh':
      case 'zh-hk':
        return MangaFormat.manhua;
      case 'ja':
        return MangaFormat.manga;
    }
    return MangaFormat.unknown;
  }

  static MangaCountryOfOrigin? _parseCountry(Object? originalLanguage) {
    if (originalLanguage is! String) return null;
    switch (originalLanguage) {
      case 'ja':
        return MangaCountryOfOrigin.jp;
      case 'ko':
        return MangaCountryOfOrigin.kr;
      case 'zh':
        return MangaCountryOfOrigin.cn;
      case 'zh-hk':
        return MangaCountryOfOrigin.tw;
    }
    return MangaCountryOfOrigin(originalLanguage.toUpperCase());
  }
}
