import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/animeav1_error.dart';

final class AnimeAv1SourcePlugin implements SourcePlugin {
  AnimeAv1SourcePlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://animeav1.com/');

  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.animeav1',
    displayName: 'AnimeAV1',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.animeDetail,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    baseUrls: <String>['https://animeav1.com'],
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    for (final candidateQuery in _buildSearchFallbacks(query.query)) {
      final uri = _baseUri.resolve(
        'catalogo?search=${Uri.encodeQueryComponent(candidateQuery)}',
      );
      final htmlResult = await _fetchHtml(uri);

      if (htmlResult.isFailure) {
        return htmlResult.fold(
          onFailure: Failure.new,
          onSuccess: (_) => throw StateError('unreachable'),
        );
      }

      try {
        final html = htmlResult.fold(
          onFailure: (_) => throw StateError('unreachable'),
          onSuccess: (value) => value,
        );
        final matches = _parseSearchMatches(html, limit: query.limit);
        if (matches.isNotEmpty) {
          return Success(matches);
        }
      } catch (error) {
        return Failure(
          AnimeAv1ParseError(
            message: 'Failed to parse AnimeAV1 search: $error',
          ),
        );
      }
    }

    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    final slug = _normalizeSourceId(sourceId);
    final uri = _baseUri.resolve('media/$slug');
    final htmlResult = await _fetchHtml(uri);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final document = html_parser.parse(html);
          final title = document.querySelector('main h1')?.text.trim() ?? '';
          if (title.isEmpty) {
            return const Failure(
              AnimeAv1ParseError(
                message: 'AnimeAV1 detail title was not found.',
              ),
            );
          }

          final synopsis = document.querySelector('main .entry p')?.text.trim();
          final nativeTitle = document.querySelector('main h2')?.text.trim();
          final metadataLine = document
              .querySelector(
                'main header div.flex.flex-wrap.items-center.gap-2.text-sm',
              )
              ?.text
              .trim();

          return Success(
            SourceAnimeDetail(
              sourceId: slug,
              title: title,
              synopsis: synopsis?.isEmpty == true ? nativeTitle : synopsis,
              releaseYear: _extractYear(metadataLine),
              format: _mapFormat(metadataLine),
            ),
          );
        } catch (error) {
          return Failure(
            AnimeAv1ParseError(
              message: 'Failed to parse AnimeAV1 detail: $error',
            ),
          );
        }
      },
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    final slug = _normalizeSourceId(sourceId);
    final uri = _baseUri.resolve('media/$slug');
    final htmlResult = await _fetchHtml(uri);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final document = html_parser.parse(html);
          final bootstrapSlug = _extractBootstrapSlug(html) ?? slug;
          final bootstrapEpisodes = _extractEpisodesFromBootstrap(
            html,
            bootstrapSlug,
          );
          final domEpisodes = _extractEpisodesFromDom(document, bootstrapSlug);
          final episodes = _mergeEpisodes(bootstrapEpisodes, domEpisodes);

          if (episodes.isEmpty) {
            return const Failure(
              AnimeAv1SourceEmptyError(
                message: 'AnimeAV1 returned no episodes for this anime.',
              ),
            );
          }

          episodes.sort((a, b) => a.number.compareTo(b.number));
          return Success(episodes);
        } catch (error) {
          return Failure(
            AnimeAv1ParseError(
              message: 'Failed to parse AnimeAV1 episodes: $error',
            ),
          );
        }
      },
    );
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    final episodePath = episode.episodeUrl.path.startsWith('/')
        ? episode.episodeUrl.path.substring(1)
        : episode.episodeUrl.path;
    final uri = _baseUri.resolve(episodePath);
    final htmlResult = await _fetchHtml(uri);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final links = _extractServerLinksFromBootstrap(html);
          return Success(links);
        } catch (error) {
          return Failure(
            AnimeAv1ParseError(
              message: 'Failed to parse AnimeAV1 episode server links: $error',
            ),
          );
        }
      },
    );
  }

  Future<Result<String, KumoriyaError>> _fetchHtml(Uri uri) async {
    try {
      final response = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return Failure(
          AnimeAv1TransportError(
            message:
                'AnimeAV1 request failed with status ${response.statusCode}.',
          ),
        );
      }
      return Success(response.body);
    } catch (error) {
      return Failure(
        AnimeAv1TransportError(message: 'AnimeAV1 request failed: $error'),
      );
    }
  }

  List<SourceAnimeMatch> _parseSearchMatches(
    String html, {
    required int limit,
  }) {
    final document = html_parser.parse(html);
    final articles = document.querySelectorAll('article');
    final matches = <SourceAnimeMatch>[];
    final seenIds = <String>{};

    for (final article in articles) {
      final linkEl = article.querySelector('a[href*="/media/"]');
      final href = linkEl?.attributes['href'] ?? '';
      final slug = _extractSlugFromMediaPath(href);
      if (slug == null || !seenIds.add(slug)) {
        continue;
      }

      final title = article.querySelector('h3')?.text.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }

      final imageUrl = article.querySelector('img')?.attributes['src'];
      final formatText = article
          .querySelector('div.rounded.bg-line, div.rounded')
          ?.text
          .trim();

      matches.add(
        SourceAnimeMatch(
          sourceId: slug,
          title: title,
          thumbnailUrl: _asAbsoluteUri(imageUrl),
          format: _mapFormat(formatText),
        ),
      );

      if (matches.length >= limit) {
        break;
      }
    }

    return matches;
  }

  List<String> _buildSearchFallbacks(String rawQuery) {
    final ordered = <String>[];
    final seen = <String>{};

    String normalizationKey(String value) {
      return _stripDiacritics(
        value.trim().toLowerCase(),
      ).replaceAll(RegExp(r'\s+'), ' ');
    }

    void add(String value) {
      final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty) {
        return;
      }
      final key = normalizationKey(normalized);
      if (seen.add(key)) {
        ordered.add(normalized);
      }
    }

    final query = rawQuery.trim();
    add(query);

    final withoutSeason = _stripSeasonDescriptor(query);
    add(withoutSeason);

    final withoutParenthetical = _stripTrailingParenthetical(withoutSeason);
    add(withoutParenthetical);

    final slugQuery = _searchQueryFromSlug(_slugify(query));
    if (normalizationKey(slugQuery) != normalizationKey(query)) {
      add(slugQuery);
    }

    return ordered;
  }

  String _stripSeasonDescriptor(String value) {
    var result = value.trim();
    const patterns = <String>[
      r'\s*[-:]?\s*\b\d+(?:st|nd|rd|th)?\s+season\b$',
      r'\s*[-:]?\s*\bseason\s+\d+\b$',
      r'\s*[-:]?\s*\bpart\s+\d+\b$',
      r'\s*[-:]?\s*\bcour\s+\d+\b$',
      r'\s*[-:]?\s*\b(?:ii|iii|iv|v)\b$',
    ];

    for (final pattern in patterns) {
      result = result.replaceFirst(RegExp(pattern, caseSensitive: false), '');
    }

    return result.trim();
  }

  String _stripTrailingParenthetical(String value) {
    return value.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  String _searchQueryFromSlug(String slug) => slug.replaceAll('-', ' ').trim();

  String _slugify(String value) {
    final lower = _stripDiacritics(value.toLowerCase());
    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _stripDiacritics(String value) {
    return value
        .replaceAll('\u00E1', 'a')
        .replaceAll('\u00E0', 'a')
        .replaceAll('\u00E4', 'a')
        .replaceAll('\u00E2', 'a')
        .replaceAll('\u00E9', 'e')
        .replaceAll('\u00E8', 'e')
        .replaceAll('\u00EB', 'e')
        .replaceAll('\u00EA', 'e')
        .replaceAll('\u00ED', 'i')
        .replaceAll('\u00EC', 'i')
        .replaceAll('\u00EF', 'i')
        .replaceAll('\u00EE', 'i')
        .replaceAll('\u00F3', 'o')
        .replaceAll('\u00F2', 'o')
        .replaceAll('\u00F6', 'o')
        .replaceAll('\u00F4', 'o')
        .replaceAll('\u00FA', 'u')
        .replaceAll('\u00F9', 'u')
        .replaceAll('\u00FC', 'u')
        .replaceAll('\u00FB', 'u')
        .replaceAll('\u00F1', 'n');
  }

  List<SourceServerLink> _extractServerLinksFromBootstrap(String html) {
    final payloadMatch = RegExp(
      r'embeds:\{([\s\S]*?)\},\s*downloads:',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(html);
    final payload = payloadMatch?.group(1) ?? html;
    final languageBlocks = RegExp(
      r'([A-Z]+):\[(.*?)\](?=,[A-Z]+:\[|$)',
      multiLine: true,
      caseSensitive: false,
    );
    final serverPattern = RegExp(
      r'server:"([^"]+)",url:"([^"]+)"',
      multiLine: true,
      caseSensitive: false,
    );

    final links = <SourceServerLink>[];
    final seenKeys = <String>{};
    var index = 0;

    for (final languageMatch in languageBlocks.allMatches(payload)) {
      final language = _mapLanguageLabel(languageMatch.group(1));
      final block = languageMatch.group(2) ?? '';

      for (final serverMatch in serverPattern.allMatches(block)) {
        final serverName = serverMatch.group(1)?.trim() ?? '';
        final rawUrl = serverMatch.group(2)?.replaceAll(r'\/', '/') ?? '';
        final uri = Uri.tryParse(rawUrl);
        if (serverName.isEmpty ||
            uri == null ||
            !uri.hasScheme ||
            uri.host.isEmpty ||
            !seenKeys.add(uri.toString())) {
          continue;
        }

        links.add(
          SourceServerLink(
            serverId: '$index-${serverName.toLowerCase().replaceAll(' ', '-')}',
            serverName: serverName,
            initialUrl: uri,
            language: language,
            detectedHost: uri.host,
          ),
        );
        index++;
      }
    }

    if (links.isNotEmpty) {
      return links;
    }

    for (final serverMatch in serverPattern.allMatches(payload)) {
      final serverName = serverMatch.group(1)?.trim() ?? '';
      final rawUrl = serverMatch.group(2)?.replaceAll(r'\/', '/') ?? '';
      final uri = Uri.tryParse(rawUrl);
      if (serverName.isEmpty ||
          uri == null ||
          !uri.hasScheme ||
          uri.host.isEmpty ||
          !seenKeys.add(uri.toString())) {
        continue;
      }

      links.add(
        SourceServerLink(
          serverId: '$index-${serverName.toLowerCase().replaceAll(' ', '-')}',
          serverName: serverName,
          initialUrl: uri,
          detectedHost: uri.host,
        ),
      );
      index++;
    }

    return links;
  }

  List<SourceEpisode> _extractEpisodesFromBootstrap(String html, String slug) {
    final blockMatch = RegExp(
      r'episodes:\[(.*?)\],relations:',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(html);
    final block = blockMatch?.group(1);
    if (block == null || block.isEmpty) {
      return const <SourceEpisode>[];
    }

    final matches = RegExp(
      r'\{id:\d+,number:(\d+(?:\.\d+)?)\}',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(block);

    return _buildEpisodesFromNumbers(
      matches
          .map((match) => double.tryParse(match.group(1) ?? ''))
          .whereType<double>(),
      slug,
    );
  }

  List<SourceEpisode> _extractEpisodesFromDom(dynamic document, String slug) {
    final links = document.querySelectorAll('a[href^="/media/$slug/"]');
    final numbers = <double>[];

    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      final number = _extractEpisodeNumberFromMediaPath(href);
      if (number != null) {
        numbers.add(number);
      }
    }

    return _buildEpisodesFromNumbers(numbers, slug);
  }

  List<SourceEpisode> _buildEpisodesFromNumbers(
    Iterable<double> numbers,
    String slug,
  ) {
    final episodes = <SourceEpisode>[];
    final seenNumbers = <double>{};

    for (final number in numbers) {
      if (!seenNumbers.add(number)) {
        continue;
      }

      final numberStr = _formatNumber(number);
      episodes.add(
        SourceEpisode(
          sourceEpisodeId: '${slug}_$numberStr',
          number: number,
          title: 'Episodio $numberStr',
          episodeUrl: _baseUri.resolve('media/$slug/$numberStr'),
        ),
      );
    }

    return episodes;
  }

  List<SourceEpisode> _mergeEpisodes(
    List<SourceEpisode> primary,
    List<SourceEpisode> fallback,
  ) {
    final mergedByNumber = <double, SourceEpisode>{};

    for (final episode in primary) {
      mergedByNumber[episode.number] = episode;
    }
    for (final episode in fallback) {
      mergedByNumber.putIfAbsent(episode.number, () => episode);
    }

    return mergedByNumber.values.toList();
  }

  String _normalizeSourceId(String sourceId) {
    final trimmed = sourceId.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return _extractSlugFromMediaPath(uri.path) ?? trimmed;
    }
    return trimmed.replaceAll('/', '');
  }

  String? _extractSlugFromMediaPath(String path) {
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length >= 2 && segments[0] == 'media') {
      return segments[1];
    }
    return null;
  }

  String? _extractBootstrapSlug(String html) {
    final match = RegExp(
      r'votes:\d+,slug:"([^"]+)"',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1)?.trim();
  }

  double? _extractEpisodeNumberFromMediaPath(String path) {
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length >= 3 && segments[0] == 'media') {
      return double.tryParse(segments[2]);
    }
    return null;
  }

  AnimeFormat _mapFormat(String? raw) {
    if (raw == null) {
      return AnimeFormat.unknown;
    }
    final value = raw.toLowerCase().trim();
    if (value.contains('tv anime') ||
        value == 'tv' ||
        value.contains('anime')) {
      return AnimeFormat.tv;
    }
    if (value.contains('película') ||
        value.contains('pelicula') ||
        value.contains('movie')) {
      return AnimeFormat.movie;
    }
    if (value.contains('ova')) {
      return AnimeFormat.ova;
    }
    if (value.contains('ona')) {
      return AnimeFormat.ona;
    }
    if (value.contains('especial') || value.contains('special')) {
      return AnimeFormat.special;
    }
    return AnimeFormat.unknown;
  }

  int? _extractYear(String? text) {
    if (text == null) {
      return null;
    }
    final match = RegExp(r'(19|20)\d{2}').firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  String? _mapLanguageLabel(String? key) {
    final normalized = key?.trim().toUpperCase() ?? '';
    switch (normalized) {
      case 'SUB':
        return 'sub';
      case 'DUB':
        return 'dub';
      default:
        return normalized.isEmpty ? null : normalized.toLowerCase();
    }
  }

  Uri? _asAbsoluteUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.startsWith('//')) {
      return Uri.tryParse('https:$trimmed');
    }
    if (trimmed.startsWith('/')) {
      return _baseUri.resolve(trimmed.substring(1));
    }
    return Uri.tryParse(trimmed);
  }

  String _formatNumber(double number) {
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
}
