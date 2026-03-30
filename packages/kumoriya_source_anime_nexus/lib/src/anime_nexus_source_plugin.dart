import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/anime_nexus_source_error.dart';

final _whitespaceRe = RegExp(r'\s+');
final _trailingParenRe = RegExp(r'\s*\([^)]*\)\s*$');
final _multiDashRe = RegExp(r'-+');
final _leadTrailDashRe = RegExp(r'^-|-$');
final _htmlTitleRe = RegExp(
  r'<title>(.*?)</title>',
  caseSensitive: false,
  dotAll: true,
);
final _watchPrefixRe = RegExp(r'^Watch\s+', caseSensitive: false);
final _onlineFreeRe = RegExp(
  r'\s+(?:TV|Movie|OVA|ONA|Special)\s+Online Free.*$',
  caseSensitive: false,
);
final _pipeAnimeSuffixRe = RegExp(
  r'\s*\|\s*(?:TV|Movie|OVA|ONA|Special)\s+Anime.*$',
  caseSensitive: false,
);
final _formatRe = RegExp(
  r'\b(TV|Movie|OVA|ONA|Special)\b',
  caseSensitive: false,
);
final _guidSuffixRe = RegExp(r'-[a-f0-9]{20}$');
final _seasonDescriptorPatterns = <RegExp>[
  RegExp(r'\s*[-:]?\s*\b\d+(?:st|nd|rd|th)?\s+season\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\bseason\s+\d+\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\bpart\s+\d+\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\bcour\s+\d+\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\b(?:ii|iii|iv|v)\b$', caseSensitive: false),
];

const _diacriticMap = <String, String>{
  '\u00E1': 'a',
  '\u00E0': 'a',
  '\u00E4': 'a',
  '\u00E2': 'a',
  '\u00E9': 'e',
  '\u00E8': 'e',
  '\u00EB': 'e',
  '\u00EA': 'e',
  '\u00ED': 'i',
  '\u00EC': 'i',
  '\u00EF': 'i',
  '\u00EE': 'i',
  '\u00F3': 'o',
  '\u00F2': 'o',
  '\u00F6': 'o',
  '\u00F4': 'o',
  '\u00FA': 'u',
  '\u00F9': 'u',
  '\u00FC': 'u',
  '\u00FB': 'u',
  '\u00F1': 'n',
};

final class AnimeNexusSourcePlugin implements SourcePlugin {
  AnimeNexusSourcePlugin({
    Dio? dio,
    Future<String?> Function(Uri uri)? seriesPageFetcher,
  }) : _dio = dio ?? _buildDio(),
       _seriesPageFetcher = seriesPageFetcher;

  final Dio _dio;
  final Future<String?> Function(Uri uri)? _seriesPageFetcher;

  static const String _base = 'https://anime.nexus';
  static const String _apiBase = 'https://api.anime.nexus';
  static const int _searchRetryAttempts = 3;

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
    KumoriyaError? lastError;
    for (final candidateQuery in _buildSearchFallbacks(query.query)) {
      try {
        final response = await _searchShows(
          query: candidateQuery,
          page: query.page,
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

        if (matches.isNotEmpty || candidateQuery == query.query.trim()) {
          return Success(matches.take(query.limit).toList(growable: false));
        }
      } on DioException catch (error) {
        lastError = AnimeNexusSourceTransportError(
          message: _searchErrorMessage(error, candidateQuery),
        );
      } catch (error) {
        lastError = AnimeNexusSourceParseError(
          message:
              'Anime Nexus search parse error for "$candidateQuery": $error',
        );
      }
    }

    if (lastError != null) {
      return Failure(lastError);
    }

    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    final seriesRef = _decodeSourceId(sourceId);
    if (seriesRef.slug == null || seriesRef.slug!.isEmpty) {
      return const Failure(
        AnimeNexusSourceParseError(
          message:
              'Anime Nexus detail requires a slug-bearing source id from search results.',
        ),
      );
    }

    final htmlDetail = await _fetchSeriesDetailFromHtml(
      sourceId: sourceId,
      seriesRef: seriesRef,
    );
    if (htmlDetail is Success<SourceAnimeDetail, KumoriyaError>) {
      return htmlDetail;
    }

    try {
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
        return _fetchSeriesDetailFromHtml(
          sourceId: sourceId,
          seriesRef: seriesRef,
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

  Future<Result<SourceAnimeDetail, KumoriyaError>> _fetchSeriesDetailFromHtml({
    required String sourceId,
    required ({String id, String? slug}) seriesRef,
  }) async {
    final slug = seriesRef.slug;
    if (slug == null || slug.isEmpty) {
      return const Failure(
        AnimeNexusSourceParseError(
          message: 'Anime Nexus detail payload could not be located.',
        ),
      );
    }

    try {
      final seriesPageUri = Uri.parse('$_base/series/${seriesRef.id}/$slug');
      final html =
          (await (_seriesPageFetcher ?? _fetchSeriesPageHtml)(
            seriesPageUri,
          ))?.trim() ??
          '';
      if (html.isEmpty) {
        return const Failure(
          AnimeNexusSourceParseError(
            message: 'Anime Nexus detail payload could not be located.',
          ),
        );
      }

      final normalizedHtml = html.replaceAll(r'\"', '"').replaceAll("\\'", "'");

      final rawTitle =
          _extractMetaContent(normalizedHtml, 'og:title') ??
          _extractHtmlTitle(normalizedHtml);
      final title = _normalizeSeriesPageTitle(rawTitle);
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
          synopsis: _extractMetaContent(normalizedHtml, 'og:description'),
          format: _parseFormatFromSeriesHtml(rawTitle),
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

      // Subtitles are fetched by the resolver during authentication and
      // merged into the ResolvedServerLinkResult.  The source plugin cannot
      // reliably call the stream API without the full auth handshake.

      final links = languages
          .map(
            (language) => SourceServerLink(
              serverId: 'anime.nexus.$language',
              serverName: 'anime.nexus ($language)',
              initialUrl: episode.episodeUrl,
              language: language,
              linkType: SourceServerLinkType.stream,
              detectedHost: 'anime.nexus',
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

  static Future<String?> _fetchSeriesPageHtml(Uri uri) async {
    final client = HttpClient();
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/146.0.0.0 Safari/537.36';

    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        'Accept',
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      request.headers.set('Accept-Language', 'es-419,es;q=0.9,en;q=0.8');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw AnimeNexusSourceTransportError(
          message:
              'Anime Nexus detail page fetch failed with status ${response.statusCode}.',
        );
      }

      final html = await response.transform(SystemEncoding().decoder).join();
      return html;
    } on HttpException catch (error) {
      throw AnimeNexusSourceTransportError(
        message: 'Anime Nexus detail page fetch failed: $error',
      );
    } on SocketException catch (error) {
      throw AnimeNexusSourceTransportError(
        message: 'Anime Nexus detail page fetch failed: $error',
      );
    } finally {
      client.close(force: true);
    }
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

  String? _extractMetaContent(String html, String property) {
    final propertyPattern = RegExp.escape(property);
    final patterns = <RegExp>[
      RegExp(
        '<meta[^>]+property=["\']$propertyPattern["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']$propertyPattern["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+name=["\']$propertyPattern["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final content = pattern.firstMatch(html)?.group(1)?.trim();
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    return null;
  }

  String? _extractHtmlTitle(String html) {
    return _htmlTitleRe.firstMatch(html)?.group(1)?.trim();
  }

  String _normalizeSeriesPageTitle(String? rawTitle) {
    var title = rawTitle?.trim() ?? '';
    if (title.isEmpty) {
      return title;
    }

    title = title.replaceFirst(_watchPrefixRe, '');
    title = title.replaceFirst(_onlineFreeRe, '');
    title = title.replaceFirst(_pipeAnimeSuffixRe, '');

    return title.trim();
  }

  AnimeFormat _parseFormatFromSeriesHtml(String? rawTitle) {
    final title = rawTitle?.trim() ?? '';
    if (title.isEmpty) {
      return AnimeFormat.unknown;
    }

    final formatMatch = _formatRe.firstMatch(title);
    return _parseFormat(formatMatch?.group(1));
  }

  String _searchQueryFromSlug(String slug) {
    final withoutGuid = slug.replaceFirst(_guidSuffixRe, '');
    return withoutGuid.replaceAll('-', ' ').trim();
  }

  List<String> _buildSearchFallbacks(String rawQuery) {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String value) {
      final normalized = value.trim().replaceAll(_whitespaceRe, ' ');
      if (normalized.isEmpty) {
        return;
      }
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        ordered.add(normalized);
      }
    }

    final query = rawQuery.trim();
    add(query);

    final withoutSeason = _stripSeasonDescriptor(query);
    add(withoutSeason);
    add(_stripTrailingParenthetical(withoutSeason));
    add(_extractRootTitle(withoutSeason));
    add(_searchQueryFromSlug(_slugify(query)));

    return ordered;
  }

  Future<Response<Map<String, dynamic>>> _searchShows({
    required String query,
    required int page,
  }) async {
    DioException? lastError;

    for (var attempt = 1; attempt <= _searchRetryAttempts; attempt++) {
      try {
        return await _dio.get<Map<String, dynamic>>(
          '$_apiBase/api/anime/shows',
          queryParameters: <String, Object>{
            'search': query,
            'page': page,
            'sortBy': 'name asc',
            'hasVideos': true,
            'includes[]': <String>['poster', 'genres', 'background'],
          },
          options: Options(headers: _apiHeaders()),
        );
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldRetrySearch(error) || attempt == _searchRetryAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: '$_apiBase/api/anime/shows'),
          message: 'Anime Nexus search failed without a concrete Dio error.',
        );
  }

  bool _shouldRetrySearch(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        return statusCode == 429 || (statusCode != null && statusCode >= 500);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
    }
  }

  String _searchErrorMessage(DioException error, String query) {
    final statusCode = error.response?.statusCode;
    final detail = error.message?.trim();
    return 'Anime Nexus search failed for "$query" '
        '(type=${error.type.name}'
        '${statusCode == null ? '' : ', status=$statusCode'}): '
        '${detail?.isNotEmpty == true ? detail : 'unknown transport error'}';
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

  String _stripSeasonDescriptor(String value) {
    var result = value.trim();

    for (final pattern in _seasonDescriptorPatterns) {
      result = result.replaceFirst(pattern, '');
    }

    return result.trim();
  }

  String _stripTrailingParenthetical(String value) {
    return value.replaceFirst(_trailingParenRe, '').trim();
  }

  String _extractRootTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final colonIndex = trimmed.indexOf(':');
    final dashIndex = trimmed.indexOf(' - ');
    final splitIndex = <int>[colonIndex, dashIndex]
        .where((index) => index > 0)
        .fold<int?>(null, (current, index) {
          if (current == null || index < current) {
            return index;
          }
          return current;
        });

    if (splitIndex == null) {
      return trimmed;
    }

    final root = trimmed.substring(0, splitIndex).trim();
    if (root.split(' ').length < 2 || root.length < 6) {
      return trimmed;
    }
    return root;
  }

  String _slugify(String value) {
    final lower = _stripDiacritics(value.toLowerCase());
    final buffer = StringBuffer();
    var previousWasDash = false;

    for (final codeUnit in lower.codeUnits) {
      final isLetter = codeUnit >= 97 && codeUnit <= 122;
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      if (isLetter || isDigit) {
        buffer.writeCharCode(codeUnit);
        previousWasDash = false;
        continue;
      }

      if (!previousWasDash) {
        buffer.write('-');
        previousWasDash = true;
      }
    }

    return buffer
        .toString()
        .replaceAll(_multiDashRe, '-')
        .replaceAll(_leadTrailDashRe, '');
  }

  String _stripDiacritics(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      buffer.write(_diacriticMap[value[i]] ?? value[i]);
    }
    return buffer.toString();
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
