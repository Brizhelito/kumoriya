import 'package:dio/dio.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/anime_nexus_source_error.dart';

final class AnimeNexusSourcePlugin implements SourcePlugin {
  AnimeNexusSourcePlugin({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static const String _base = 'https://anime.nexus';
  static const String _apiBase = 'https://api.anime.nexus';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.anime_nexus',
    displayName: 'anime.nexus',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.animeDetail,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    baseUrls: <String>['https://anime.nexus'],
    usesWebView: false,
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiBase/api/anime/shows',
        queryParameters: <String, Object>{
          'search': query.query.trim(),
          'page': query.page,
          'sortBy': 'name asc',
          'hasVideos': true,
          'includes[]': <String>['poster', 'genres', 'background'],
        },
        options: Options(headers: _apiHeaders()),
      );

      final items = response.data?['data'] as List<dynamic>? ?? const [];
      final matches = <SourceAnimeMatch>[];

      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final sourceId = item['id']?.toString().trim() ?? '';
        final slug = item['slug']?.toString().trim() ?? '';
        final title = item['name']?.toString().trim() ?? '';
        if (sourceId.isEmpty || slug.isEmpty || title.isEmpty) {
          continue;
        }

        matches.add(
          SourceAnimeMatch(
            sourceId: _encodeSourceId(sourceId, slug),
            title: title,
            thumbnailUrl: _thumbnailUrl(item),
            releaseYear:
                _parseYear(item['year']) ?? _parseYear(item['release_date']),
            format: _parseFormat(item['type']),
          ),
        );
      }

      return Success(matches.take(query.limit).toList(growable: false));
    } on DioException catch (error) {
      return Failure(
        AnimeNexusSourceTransportError(
          message: 'Anime Nexus search failed: ${error.message}',
        ),
      );
    } catch (error) {
      return Failure(
        AnimeNexusSourceParseError(
          message: 'Anime Nexus search parse error: $error',
        ),
      );
    }
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    try {
      final seriesRef = _decodeSourceId(sourceId);
      if (seriesRef.slug == null || seriesRef.slug!.isEmpty) {
        return const Failure(
          AnimeNexusSourceParseError(
            message:
                'Anime Nexus detail requires a slug-bearing source id from search results.',
          ),
        );
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiBase/api/anime/shows',
        queryParameters: <String, Object>{
          'search': _searchQueryFromSlug(seriesRef.slug!),
          'page': 1,
          'sortBy': 'name asc',
          'hasVideos': true,
          'includes[]': <String>['poster', 'genres', 'background'],
        },
        options: Options(headers: _apiHeaders()),
      );

      final items = response.data?['data'] as List<dynamic>? ?? const [];
      final payload = items
          .whereType<Map<String, dynamic>>()
          .cast<Map<String, dynamic>?>()
          .firstWhere(
            (item) =>
                item?['id']?.toString().trim() == seriesRef.id ||
                item?['slug']?.toString().trim() == seriesRef.slug,
            orElse: () => null,
          );
      if (payload == null) {
        return const Failure(
          AnimeNexusSourceParseError(
            message: 'Anime Nexus detail payload could not be located.',
          ),
        );
      }

      final title = payload['name']?.toString().trim() ?? '';
      if (title.isEmpty) {
        return const Failure(
          AnimeNexusSourceParseError(
            message: 'Anime Nexus detail title was not found.',
          ),
        );
      }

      return Success(
        SourceAnimeDetail(
          sourceId: sourceId,
          title: title,
          synopsis: payload['description']?.toString().trim(),
          thumbnailUrl: _thumbnailUrl(payload),
          releaseYear:
              _parseYear(payload['year']) ??
              _parseYear(payload['release_date']),
          format: _parseFormat(payload['type']),
        ),
      );
    } on DioException catch (error) {
      return Failure(
        AnimeNexusSourceTransportError(
          message: 'Anime Nexus detail fetch failed: ${error.message}',
        ),
      );
    } catch (error) {
      return Failure(
        AnimeNexusSourceParseError(
          message: 'Anime Nexus detail parse error: $error',
        ),
      );
    }
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    try {
      final seriesRef = _decodeSourceId(sourceId);
      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiBase/api/anime/details/episodes',
        queryParameters: <String, Object>{
          'id': seriesRef.id,
          'page': 1,
          'perPage': 100,
          'order': 'asc',
          'fillers': true,
          'recaps': true,
        },
        options: Options(headers: _apiHeaders()),
      );

      final items = response.data?['data'] as List<dynamic>? ?? const [];
      final episodes = <SourceEpisode>[];

      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final episodeId = item['id']?.toString().trim() ?? '';
        final rawNumber = item['number'];
        final number = switch (rawNumber) {
          num value => value.toDouble(),
          String value => double.tryParse(value.trim()),
          _ => null,
        };
        if (episodeId.isEmpty || number == null) {
          continue;
        }

        final slug = item['slug']?.toString().trim() ?? '';
        final episodeLabel = number == number.truncateToDouble()
            ? number.toInt().toString()
            : number.toString();
        if (slug.isEmpty) {
          continue;
        }

        episodes.add(
          SourceEpisode(
            sourceEpisodeId: episodeId,
            number: number,
            title: item['title']?.toString().trim().isNotEmpty == true
                ? item['title']!.toString().trim()
                : 'Episode $episodeLabel',
            episodeUrl: Uri.parse('$_base/watch/$episodeId/$slug'),
            thumbnailUrl: _episodeThumbnail(item),
          ),
        );
      }

      if (episodes.isEmpty) {
        return const Failure(
          AnimeNexusSourceEmptyError(
            message: 'Anime Nexus returned no episodes for this anime.',
          ),
        );
      }

      episodes.sort((a, b) => a.number.compareTo(b.number));
      return Success(episodes);
    } on DioException catch (error) {
      return Failure(
        AnimeNexusSourceTransportError(
          message: 'Anime Nexus episodes fetch failed: ${error.message}',
        ),
      );
    } catch (error) {
      return Failure(
        AnimeNexusSourceParseError(
          message: 'Anime Nexus episodes parse error: $error',
        ),
      );
    }
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    try {
      // Fetch the watch page for language detection (sub/dub/jpn).
      final pageResponse = await _dio.get<String>(
        episode.episodeUrl.toString(),
        options: Options(
          responseType: ResponseType.plain,
          headers: _pageHeaders(episode.episodeUrl),
        ),
      );

      final body = pageResponse.data?.trim() ?? '';
      if (body.isEmpty) {
        return Failure(
          AnimeNexusSourceEmptyError(
            message:
                'Anime Nexus watch page was empty for ${episode.episodeUrl}.',
          ),
        );
      }

      final languages = _extractLanguages(body);

      // Fetch subtitles from the structured API instead of HTML scraping.
      final subtitles = await _fetchApiSubtitles(
        episodeId: episode.sourceEpisodeId,
      );

      final links = languages
          .map(
            (language) => SourceServerLink(
              serverId: 'anime.nexus.$language',
              serverName: 'anime.nexus ($language)',
              initialUrl: episode.episodeUrl,
              language: language,
              linkType: SourceServerLinkType.stream,
              detectedHost: 'anime.nexus',
              externalSubtitles: subtitles,
            ),
          )
          .toList(growable: false);

      return Success(links);
    } on DioException catch (error) {
      return Failure(
        AnimeNexusSourceTransportError(
          message: 'Anime Nexus server links fetch failed: ${error.message}',
        ),
      );
    } catch (error) {
      return Failure(
        AnimeNexusSourceParseError(
          message: 'Anime Nexus server link parse error: $error',
        ),
      );
    }
  }

  /// Fetches subtitles from the episode/stream API endpoint.
  ///
  /// The API returns `data.subtitles[]` with `src`, `label`, and `srcLang`
  /// fields, which is more reliable than parsing them out of the HTML page.
  /// Returns an empty list if the call fails or no subtitles are present.
  Future<List<ExternalSubtitleTrack>> _fetchApiSubtitles({
    required String episodeId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiBase/api/anime/details/episode/stream',
        queryParameters: <String, Object>{
          'id': episodeId,
          'fillers': true,
          'recaps': true,
        },
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: <String, String>{
            'Accept': 'application/json, text/plain, */*',
            'Referer': '$_base/watch/$episodeId',
            'Origin': _base,
            'sec-fetch-dest': 'empty',
            'sec-fetch-mode': 'cors',
            'sec-fetch-site': 'same-site',
          },
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return const <ExternalSubtitleTrack>[];
      }

      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) {
        return const <ExternalSubtitleTrack>[];
      }

      final rawSubtitles = data['subtitles'];
      if (rawSubtitles is! List<dynamic>) {
        return const <ExternalSubtitleTrack>[];
      }

      final byUrl = <String, ExternalSubtitleTrack>{};
      for (final item in rawSubtitles) {
        if (item is! Map<String, dynamic>) continue;

        final src = item['src']?.toString().trim() ?? '';
        if (src.isEmpty) continue;

        final uri = Uri.tryParse(src);
        if (uri == null) continue;

        final label = item['label']?.toString().trim() ?? 'Subtitles';
        final srcLang = item['srcLang']?.toString().trim();
        final language = srcLang?.isEmpty == true ? null : srcLang;

        byUrl.putIfAbsent(
          uri.toString(),
          () => ExternalSubtitleTrack(
            id: 'subtitle-${byUrl.length}',
            label: label.isEmpty ? 'Subtitles' : label,
            language: language,
            uri: uri,
            isDefault: byUrl.isEmpty,
          ),
        );
      }

      return byUrl.values.toList(growable: false);
    } catch (_) {
      // Non-fatal: subtitles are best-effort.
      return const <ExternalSubtitleTrack>[];
    }
  }

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/146.0.0.0 Safari/537.36',
          'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br, zstd',
        },
      ),
    );
  }

  ({String id, String? slug}) _decodeSourceId(String sourceId) {
    final value = sourceId.trim();
    if (value.isEmpty) {
      return (id: value, slug: null);
    }

    final parts = value.split('::');
    if (parts.length < 2) {
      return (id: value, slug: null);
    }

    final id = parts.first.trim();
    final slug = parts.sublist(1).join('::').trim();
    return (id: id, slug: slug.isEmpty ? null : slug);
  }

  String _encodeSourceId(String id, String slug) => '$id::$slug';

  String _searchQueryFromSlug(String slug) {
    final withoutGuid = slug.replaceFirst(RegExp(r'-[a-f0-9]{20}$'), '');
    return withoutGuid.replaceAll('-', ' ').trim();
  }

  Map<String, String> _apiHeaders() {
    return const <String, String>{
      'Referer': _base,
      'Origin': _base,
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
    };
  }

  Map<String, String> _pageHeaders(Uri referer) {
    return <String, String>{
      'Referer': referer.toString(),
      'sec-fetch-dest': 'document',
      'sec-fetch-mode': 'navigate',
      'sec-fetch-site': 'same-origin',
    };
  }

  Set<String> _extractLanguages(String html) {
    final lower = html.toLowerCase();
    final languages = <String>{};

    if (lower.contains('"sub"') ||
        lower.contains('english subbed') ||
        lower.contains('subtitles')) {
      languages.add('sub');
    }
    if (lower.contains('"dub"') ||
        lower.contains('english dubbed') ||
        lower.contains('dubbed')) {
      languages.add('dub');
    }
    if (lower.contains('"jpn"') || lower.contains('japanese')) {
      languages.add('jpn');
    }

    if (languages.isEmpty) {
      languages.add('sub');
    }

    return languages;
  }

  Uri? _thumbnailUrl(Map<String, dynamic> payload) {
    final poster = payload['poster'];
    if (poster is Map<String, dynamic>) {
      final resized = poster['resized'];
      if (resized is Map<String, dynamic>) {
        return _asUri(
          resized['480x720']?.toString() ??
              resized['240x360']?.toString() ??
              resized.values.cast<Object?>().firstOrNull?.toString(),
        );
      }
      return _asUri(
        poster['original']?.toString() ?? poster['url']?.toString(),
      );
    }
    return _asUri(
      payload['thumbnail']?.toString() ?? payload['image']?.toString(),
    );
  }

  Uri? _episodeThumbnail(Map<String, dynamic> payload) {
    final image = payload['image'];
    if (image is Map<String, dynamic>) {
      final resized = image['resized'];
      if (resized is Map<String, dynamic>) {
        return _asUri(
          resized['1280x720']?.toString() ??
              resized['640x360']?.toString() ??
              resized.values.cast<Object?>().firstOrNull?.toString(),
        );
      }
      return _asUri(image['original']?.toString() ?? image['url']?.toString());
    }
    return _asUri(image?.toString());
  }

  Uri? _asUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final normalized = raw.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Uri.tryParse(normalized);
    }
    if (normalized.startsWith('/')) {
      return Uri.tryParse('https://anime.delivery$normalized');
    }
    return Uri.tryParse(normalized);
  }

  int? _parseYear(Object? value) {
    return switch (value) {
      int year => year,
      String year => int.tryParse(year.trim()),
      _ => null,
    };
  }

  AnimeFormat _parseFormat(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'tv':
        return AnimeFormat.tv;
      case 'movie':
        return AnimeFormat.movie;
      case 'ova':
        return AnimeFormat.ova;
      case 'ona':
        return AnimeFormat.ona;
      case 'special':
        return AnimeFormat.special;
      default:
        return AnimeFormat.unknown;
    }
  }
}
