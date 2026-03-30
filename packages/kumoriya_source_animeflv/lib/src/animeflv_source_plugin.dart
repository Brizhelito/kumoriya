import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/animeflv_error.dart';

final _whitespaceRe = RegExp(r'\s+');
final _trailingParenRe = RegExp(r'\s*\([^)]*\)\s*$');
final _nonAlnumRe = RegExp(r'[^a-z0-9]+');
final _multiDashRe = RegExp(r'-+');
final _leadTrailDashRe = RegExp(r'^-|-$');
final _episodeNumberRe = RegExp(r'-(\d+(?:\.\d+)?)$');
final _yearRe = RegExp(r'(19|20)\d{2}');
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

/// AnimeFLV source plugin.
///
/// Search: GET /browse?q={query}
/// Detail: GET /anime/{slug}
/// Episodes: listed on detail page, URL /ver/{slug}-{number}
/// Server links: extracted from `var videos = {...}` JSON in episode page.
final class AnimeFlvSourcePlugin implements SourcePlugin {
  AnimeFlvSourcePlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://www3.animeflv.net/');

  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.animeflv',
    displayName: 'AnimeFLV',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.animeDetail,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    baseUrls: <String>['https://www3.animeflv.net'],
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    for (final candidateQuery in _buildSearchFallbacks(query.query)) {
      final uri = _baseUri.resolve(
        'browse?q=${Uri.encodeComponent(candidateQuery)}',
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
          AnimeFlvParseError(
            message: 'Failed to parse AnimeFLV search: $error',
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
    final uri = _baseUri.resolve('anime/$slug');
    final htmlResult = await _fetchHtml(uri);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final document = html_parser.parse(html);
          final title = document.querySelector('h1.Title')?.text.trim() ?? '';
          if (title.isEmpty) {
            return const Failure(
              AnimeFlvParseError(
                message: 'AnimeFLV detail title was not found.',
              ),
            );
          }

          final synopsis = document
              .querySelector('.Description p')
              ?.text
              .trim();
          final thumbnail = document
              .querySelector('.AnimeCover figure img')
              ?.attributes['src']
              ?.trim();
          final typeText = document.querySelector('.Type')?.text.trim();
          final statusText = document
              .querySelector('.AnmStts span')
              ?.text
              .trim();

          int? releaseYear;
          final yearText = document
              .querySelector('.AnmStts + span')
              ?.text
              .trim();
          if (yearText != null) {
            releaseYear = _extractYear(yearText);
          }

          return Success(
            SourceAnimeDetail(
              sourceId: slug,
              title: title,
              synopsis: synopsis?.isEmpty == true ? null : synopsis,
              thumbnailUrl: _asAbsoluteUri(thumbnail),
              releaseYear: releaseYear,
              format: _mapFormat(typeText ?? statusText),
            ),
          );
        } catch (error) {
          return Failure(
            AnimeFlvParseError(
              message: 'Failed to parse AnimeFLV detail: $error',
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
    final uri = _baseUri.resolve('anime/$slug');
    final htmlResult = await _fetchHtml(uri);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final episodes = _extractEpisodesFromDetailPage(html, slug: slug);
          if (episodes.isEmpty) {
            return const Failure(
              AnimeFlvSourceEmptyError(
                message: 'AnimeFLV returned no episodes for this anime.',
              ),
            );
          }

          episodes.sort((a, b) => a.number.compareTo(b.number));
          return Success(episodes);
        } catch (error) {
          return Failure(
            AnimeFlvParseError(
              message: 'Failed to parse AnimeFLV episodes: $error',
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
          final links = _extractServerLinksFromEpisodePage(html);
          return Success(links);
        } catch (error) {
          return Failure(
            AnimeFlvParseError(
              message: 'Failed to parse AnimeFLV episode server links: $error',
            ),
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Result<String, KumoriyaError>> _fetchHtml(Uri uri) async {
    try {
      final response = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return Failure(
          AnimeFlvTransportError(
            message:
                'AnimeFLV request failed with status ${response.statusCode}',
          ),
        );
      }
      return Success(response.body);
    } catch (error) {
      return Failure(
        AnimeFlvTransportError(message: 'AnimeFLV request failed: $error'),
      );
    }
  }

  List<SourceAnimeMatch> _parseSearchMatches(
    String html, {
    required int limit,
  }) {
    final document = html_parser.parse(html);
    final articles = document.querySelectorAll('ul.ListAnimes li article');
    final matches = <SourceAnimeMatch>[];
    final seenIds = <String>{};

    for (final article in articles) {
      final linkEl = article.querySelector('a[href]');
      final href = linkEl?.attributes['href'] ?? '';
      final sourceId = _extractSlugFromPath(href);
      if (sourceId == null || seenIds.contains(sourceId)) {
        continue;
      }
      seenIds.add(sourceId);

      final title = article.querySelector('h3')?.text.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }

      final imageUrl = article
          .querySelector('figure img')
          ?.attributes['src']
          ?.trim();
      final typeText = article.querySelector('.Type')?.text.trim();

      matches.add(
        SourceAnimeMatch(
          sourceId: sourceId,
          title: title,
          thumbnailUrl: _asAbsoluteUri(imageUrl),
          format: _mapFormat(typeText),
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
      ).replaceAll(_whitespaceRe, ' ');
    }

    void add(String value) {
      final normalized = value.trim().replaceAll(_whitespaceRe, ' ');
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

    for (final pattern in _seasonDescriptorPatterns) {
      result = result.replaceFirst(pattern, '');
    }

    return result.trim();
  }

  String _stripTrailingParenthetical(String value) {
    return value.replaceFirst(_trailingParenRe, '').trim();
  }

  String _searchQueryFromSlug(String slug) => slug.replaceAll('-', ' ').trim();

  String _slugify(String value) {
    final lower = _stripDiacritics(value.toLowerCase());
    return lower
        .replaceAll(_nonAlnumRe, '-')
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

  List<SourceEpisode> _extractEpisodesFromDetailPage(
    String html, {
    required String slug,
  }) {
    final document = html_parser.parse(html);
    final episodeItems = document.querySelectorAll('ul.ListCaps li');

    final episodes = <SourceEpisode>[];
    final seenNumbers = <double>{};

    for (final item in episodeItems) {
      final linkEl = item.querySelector('a[href]');
      final href = linkEl?.attributes['href']?.trim() ?? '';
      if (href.isEmpty) {
        continue;
      }

      final episodeNumber = _extractEpisodeNumberFromHref(href);
      if (episodeNumber == null || seenNumbers.contains(episodeNumber)) {
        continue;
      }
      seenNumbers.add(episodeNumber);

      final numberLabel = item.querySelector('p')?.text.trim() ?? '';
      final title = numberLabel.isNotEmpty
          ? numberLabel
          : 'Episodio ${_formatNumber(episodeNumber)}';

      episodes.add(
        SourceEpisode(
          sourceEpisodeId: '${slug}_${_formatNumber(episodeNumber)}',
          number: episodeNumber,
          title: title,
          episodeUrl: _baseUri.resolve(
            href.startsWith('/') ? href.substring(1) : href,
          ),
        ),
      );
    }

    // Fallback: parse from script var anime_info / episodes arrays
    if (episodes.isEmpty) {
      episodes.addAll(_extractEpisodesFromScript(html, slug: slug));
    }

    return episodes;
  }

  List<SourceEpisode> _extractEpisodesFromScript(
    String html, {
    required String slug,
  }) {
    // AnimeFLV embeds var episodes = [[number, id], ...]
    final pattern = RegExp(
      r'var\s+episodes\s*=\s*(\[[\s\S]*?\]);',
      caseSensitive: false,
      multiLine: true,
    );
    final match = pattern.firstMatch(html);
    if (match == null) {
      return const <SourceEpisode>[];
    }

    final rawArray = match.group(1);
    if (rawArray == null) {
      return const <SourceEpisode>[];
    }

    try {
      final decoded = jsonDecode(rawArray);
      if (decoded is! List) {
        return const <SourceEpisode>[];
      }

      final episodes = <SourceEpisode>[];
      for (final item in decoded) {
        if (item is! List || item.isEmpty) {
          continue;
        }

        final rawNumber = item[0];
        final episodeNumber = rawNumber is num
            ? rawNumber.toDouble()
            : double.tryParse(rawNumber.toString().trim());
        if (episodeNumber == null) {
          continue;
        }

        final numberStr = _formatNumber(episodeNumber);
        episodes.add(
          SourceEpisode(
            sourceEpisodeId: '${slug}_$numberStr',
            number: episodeNumber,
            title: 'Episodio $numberStr',
            episodeUrl: _baseUri.resolve('ver/$slug-$numberStr'),
          ),
        );
      }

      return episodes;
    } catch (_) {
      return const <SourceEpisode>[];
    }
  }

  List<SourceServerLink> _extractServerLinksFromEpisodePage(String html) {
    // AnimeFLV embeds: var videos = {"SUB":[...], "LAT":[...]}
    final pattern = RegExp(
      r'var\s+videos\s*=\s*(\{[\s\S]*?\});',
      caseSensitive: false,
      multiLine: true,
    );
    final match = pattern.firstMatch(html);
    if (match == null) {
      return const <SourceServerLink>[];
    }

    final rawJson = match.group(1);
    if (rawJson == null) {
      return const <SourceServerLink>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return const <SourceServerLink>[];
      }

      final links = <SourceServerLink>[];
      final seenKeys = <String>{};
      var index = 0;

      for (final entry in decoded.entries) {
        final language = _mapLanguageLabel(entry.key);
        final servers = entry.value;
        if (servers is! List) {
          continue;
        }

        for (final server in servers) {
          if (server is! Map<String, dynamic>) {
            continue;
          }

          final serverName = server['title'] is String
              ? (server['title'] as String).trim()
              : '';
          final code = server['code'] is String
              ? (server['code'] as String).trim()
              : '';

          if (serverName.isEmpty || code.isEmpty) {
            continue;
          }

          final codeUri = Uri.tryParse(code.replaceAll(r'\/', '/'));
          if (codeUri == null || !codeUri.hasScheme || codeUri.host.isEmpty) {
            continue;
          }

          final dedupeKey = '${codeUri.toString()}|$language';
          if (!seenKeys.add(dedupeKey)) {
            continue;
          }

          final downloadUrl = server['url'] is String
              ? (server['url'] as String).trim()
              : '';
          final hasDownloadUrl = downloadUrl.isNotEmpty;
          final linkType = _inferLinkType(serverName, codeUri, hasDownloadUrl);
          final detectedHost = _detectHost(serverName, codeUri);

          links.add(
            SourceServerLink(
              serverId:
                  '$index-${serverName.toLowerCase().replaceAll(' ', '-')}',
              serverName: serverName,
              initialUrl: codeUri,
              language: language,
              linkType: linkType,
              detectedHost: detectedHost,
            ),
          );
          index++;

          // If there's a separate download URL, add it too
          if (hasDownloadUrl) {
            final dlUri = Uri.tryParse(downloadUrl.replaceAll(r'\/', '/'));
            if (dlUri != null &&
                dlUri.hasScheme &&
                dlUri.host.isEmpty == false) {
              final dlDedupeKey = '${dlUri.toString()}|$language|download';
              if (seenKeys.add(dlDedupeKey)) {
                links.add(
                  SourceServerLink(
                    serverId:
                        '$index-${serverName.toLowerCase().replaceAll(' ', '-')}-dl',
                    serverName: '$serverName (Download)',
                    initialUrl: dlUri,
                    language: language,
                    linkType: SourceServerLinkType.download,
                    detectedHost: _detectHost(serverName, dlUri),
                  ),
                );
                index++;
              }
            }
          }
        }
      }

      return links;
    } catch (_) {
      return const <SourceServerLink>[];
    }
  }

  String _normalizeSourceId(String sourceId) {
    final trimmed = sourceId.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return _extractSlugFromPath(uri.path) ?? trimmed;
    }
    return trimmed.replaceAll('/', '');
  }

  String? _extractSlugFromPath(String path) {
    // /anime/naruto -> naruto
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[0] == 'anime') {
      return segments[1];
    }
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return null;
  }

  double? _extractEpisodeNumberFromHref(String href) {
    // /ver/naruto-220 -> 220
    final match = _episodeNumberRe.firstMatch(href);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  AnimeFormat _mapFormat(String? raw) {
    if (raw == null) {
      return AnimeFormat.unknown;
    }
    final value = raw.toLowerCase().trim();
    if (value.contains('anime') || value == 'tv') {
      return AnimeFormat.tv;
    }
    if (value.contains('película') ||
        value.contains('pelicula') ||
        value == 'movie') {
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

  int? _extractYear(String text) {
    final match = _yearRe.firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
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
      return _baseUri.resolve(trimmed);
    }
    return Uri.tryParse(trimmed);
  }

  String? _mapLanguageLabel(String key) {
    final normalized = key.trim().toUpperCase();
    switch (normalized) {
      case 'SUB':
        return 'sub';
      case 'LAT':
        return 'lat';
      case 'CAST':
        return 'cast';
      default:
        return normalized.isNotEmpty ? normalized.toLowerCase() : null;
    }
  }

  SourceServerLinkType _inferLinkType(
    String serverName,
    Uri url,
    bool hasDownloadUrl,
  ) {
    final name = serverName.toLowerCase();
    if (name == 'mega' || name == '1fichier' || name == 'mediafire') {
      return SourceServerLinkType.download;
    }
    return SourceServerLinkType.stream;
  }

  String _detectHost(String serverName, Uri url) {
    final name = serverName.toLowerCase().trim();
    const labelToHost = <String, String>{
      'sw': 'streamwish.to',
      'streamwish': 'streamwish.to',
      'mega': 'mega.nz',
      'yourupload': 'yourupload.com',
      'okru': 'ok.ru',
      'maru': 'my.mail.ru',
      'fembed': 'embedsito.com',
      'netu': 'hqq.tv',
      'stape': 'streamtape.com',
      'streamtape': 'streamtape.com',
      'mp4upload': 'mp4upload.com',
      'filemoon': 'filemoon.sx',
      'mixdrop': 'mixdrop.co',
      'doodstream': 'doodstream.com',
      'voe': 'voe.sx',
      '1fichier': '1fichier.com',
      'mediafire': 'mediafire.com',
      'zippyshare': 'zippyshare.com',
    };

    final fromLabel = labelToHost[name];
    if (fromLabel != null) {
      return fromLabel;
    }

    return url.host;
  }

  String _formatNumber(double number) {
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
}
