import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/animeav1_error.dart';

/// AnimeAV1 source plugin.
///
/// AnimeAV1 is a SvelteKit app that embeds SSR data in `__sveltekit_*` scripts.
/// - Catalog/search: `/catalogo?q={query}` or SSR-embedded data
/// - Detail: `/media/{slug}` with SSR data containing media info + episodes
/// - Episodes: `/media/{slug}/{number}` with server buttons
/// - Server links: extracted from SSR data embedded in page scripts
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
    final uri = _baseUri.resolve(
      'catalogo?q=${Uri.encodeComponent(query.query.trim())}',
    );
    final htmlResult = await _fetchHtml(uri);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final matches = <SourceAnimeMatch>[];
          final seenIds = <String>{};

          // Try parsing from SSR data first
          final ssrData = _extractSvelteKitData(html);
          if (ssrData != null) {
            final mediaList = _extractMediaListFromSsr(ssrData);
            for (final media in mediaList) {
              final slug = media['slug'] is String
                  ? (media['slug'] as String).trim()
                  : '';
              final title = media['title'] is String
                  ? (media['title'] as String).trim()
                  : '';
              if (slug.isEmpty || title.isEmpty || seenIds.contains(slug)) {
                continue;
              }
              seenIds.add(slug);

              final categoryId = media['categoryId'];
              final posterUrl = media['poster'] is String
                  ? (media['poster'] as String).trim()
                  : null;

              matches.add(
                SourceAnimeMatch(
                  sourceId: slug,
                  title: title,
                  thumbnailUrl: _asCdnUri(posterUrl),
                  format: _mapCategoryId(categoryId),
                ),
              );

              if (matches.length >= query.limit) {
                break;
              }
            }
          }

          // Fallback: parse from HTML structure
          if (matches.isEmpty) {
            final document = html_parser.parse(html);
            final articles = document.querySelectorAll('article');
            for (final article in articles) {
              final linkEl = article.querySelector('a[href*="/media/"]');
              final href = linkEl?.attributes['href'] ?? '';
              final slug = _extractSlugFromMediaPath(href);
              if (slug == null || seenIds.contains(slug)) {
                continue;
              }
              seenIds.add(slug);

              final title = article.querySelector('h3')?.text.trim() ?? '';
              if (title.isEmpty) {
                continue;
              }

              final imageUrl = article
                  .querySelector('img')
                  ?.attributes['src']
                  ?.trim();
              final typeText = article
                  .querySelector('.Type, [class*="type"]')
                  ?.text
                  .trim();

              matches.add(
                SourceAnimeMatch(
                  sourceId: slug,
                  title: title,
                  thumbnailUrl: _asCdnUri(imageUrl),
                  format: _mapFormat(typeText),
                ),
              );

              if (matches.length >= query.limit) {
                break;
              }
            }
          }

          return Success(matches);
        } catch (error) {
          return Failure(
            AnimeAv1ParseError(
              message: 'Failed to parse AnimeAV1 search: $error',
            ),
          );
        }
      },
    );
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
          final ssrData = _extractSvelteKitData(html);
          if (ssrData != null) {
            final media = _extractMediaFromSsr(ssrData);
            if (media != null) {
              final title = media['title'] is String
                  ? (media['title'] as String).trim()
                  : '';
              if (title.isNotEmpty) {
                final synopsis = media['synopsis'] is String
                    ? (media['synopsis'] as String).trim()
                    : null;
                final posterUrl = media['poster'] is String
                    ? (media['poster'] as String).trim()
                    : null;
                final categoryId = media['categoryId'];
                final year = media['year'];

                return Success(
                  SourceAnimeDetail(
                    sourceId: slug,
                    title: title,
                    synopsis: synopsis?.isEmpty == true ? null : synopsis,
                    thumbnailUrl: _asCdnUri(posterUrl),
                    releaseYear: year is int ? year : null,
                    format: _mapCategoryId(categoryId),
                  ),
                );
              }
            }
          }

          // Fallback: parse from HTML
          final document = html_parser.parse(html);
          final title = document.querySelector('h1')?.text.trim() ?? '';
          if (title.isEmpty) {
            return const Failure(
              AnimeAv1ParseError(
                message: 'AnimeAV1 detail title was not found.',
              ),
            );
          }

          final synopsis = document
              .querySelector('p[class*="synopsis"], .Description p')
              ?.text
              .trim();

          return Success(
            SourceAnimeDetail(
              sourceId: slug,
              title: title,
              synopsis: synopsis?.isEmpty == true ? null : synopsis,
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
          final episodes = <SourceEpisode>[];
          final seenNumbers = <double>{};

          // Extract from SSR data
          final ssrData = _extractSvelteKitData(html);
          if (ssrData != null) {
            final episodeList = _extractEpisodesFromSsr(ssrData);
            for (final ep in episodeList) {
              final id = ep['id'];
              final number = ep['number'];
              final epNumber = number is num
                  ? number.toDouble()
                  : double.tryParse(number.toString().trim());
              if (epNumber == null || seenNumbers.contains(epNumber)) {
                continue;
              }
              seenNumbers.add(epNumber);

              final numberStr = _formatNumber(epNumber);
              episodes.add(
                SourceEpisode(
                  sourceEpisodeId: id?.toString() ?? '${slug}_$numberStr',
                  number: epNumber,
                  title: 'Episodio $numberStr',
                  episodeUrl: _baseUri.resolve('media/$slug/$numberStr'),
                ),
              );
            }
          }

          // Fallback: parse from HTML links
          if (episodes.isEmpty) {
            final document = html_parser.parse(html);
            final links = document.querySelectorAll('a[href*="/media/$slug/"]');
            for (final link in links) {
              final href = link.attributes['href'] ?? '';
              final number = _extractEpisodeNumberFromMediaPath(href);
              if (number == null || seenNumbers.contains(number)) {
                continue;
              }
              seenNumbers.add(number);

              final numberStr = _formatNumber(number);
              episodes.add(
                SourceEpisode(
                  sourceEpisodeId: '${slug}_$numberStr',
                  number: number,
                  title: 'Episodio $numberStr',
                  episodeUrl: _baseUri.resolve(
                    href.startsWith('/') ? href.substring(1) : href,
                  ),
                ),
              );
            }
          }

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
          final links = _extractServerLinksFromEpisodePage(html, uri);
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

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<Result<String, KumoriyaError>> _fetchHtml(Uri uri) async {
    try {
      final response = await _httpClient.get(uri);
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

  String? _extractSvelteKitData(String html) {
    // SvelteKit embeds data in __sveltekit_* scripts with a data: [...] array
    final pattern = RegExp(
      r'__sveltekit_\w+\s*=\s*\{[\s\S]*?data:\s*\[([\s\S]*?)\]\s*,\s*\n?\s*form',
      caseSensitive: false,
      multiLine: true,
    );
    final match = pattern.firstMatch(html);
    return match?.group(1);
  }

  Map<String, dynamic>? _extractMediaFromSsr(String ssrData) {
    // Look for media:{...} pattern in SSR data
    final mediaPattern = RegExp(
      r'media:\s*(\{[^}]*(?:\{[^}]*\}[^}]*)*\})',
      caseSensitive: false,
      multiLine: true,
    );
    final match = mediaPattern.firstMatch(ssrData);
    if (match == null) {
      return null;
    }

    // This is JS object notation, not strict JSON, so we need lenient parsing
    return _parseJsObject(match.group(1) ?? '');
  }

  List<Map<String, dynamic>> _extractMediaListFromSsr(String ssrData) {
    // Look for arrays of media objects
    final results = <Map<String, dynamic>>[];
    final pattern = RegExp(
      r'\{[^{}]*?title:"([^"]+)"[^{}]*?slug:"([^"]+)"[^{}]*?\}',
      caseSensitive: false,
      multiLine: true,
    );

    for (final match in pattern.allMatches(ssrData)) {
      final title = match.group(1)?.trim() ?? '';
      final slug = match.group(2)?.trim() ?? '';
      if (title.isNotEmpty && slug.isNotEmpty) {
        results.add(<String, dynamic>{'title': title, 'slug': slug});
      }
    }

    return results;
  }

  List<Map<String, dynamic>> _extractEpisodesFromSsr(String ssrData) {
    // Episodes pattern: {id:NNN,number:NNN}
    final results = <Map<String, dynamic>>[];
    final pattern = RegExp(
      r'\{id:(\d+),number:(\d+(?:\.\d+)?)\}',
      caseSensitive: false,
      multiLine: true,
    );

    for (final match in pattern.allMatches(ssrData)) {
      final id = int.tryParse(match.group(1) ?? '');
      final number = double.tryParse(match.group(2) ?? '');
      if (id != null && number != null) {
        results.add(<String, dynamic>{'id': id, 'number': number});
      }
    }

    return results;
  }

  Map<String, dynamic>? _parseJsObject(String raw) {
    // Best-effort JS object to Map conversion
    try {
      // Replace unquoted keys with quoted keys
      final jsonLike = raw
          .replaceAllMapped(RegExp(r'(\w+)\s*:'), (m) => '"${m.group(1)}":')
          .replaceAll("'", '"');
      return jsonDecode(jsonLike) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  List<SourceServerLink> _extractServerLinksFromEpisodePage(
    String html,
    Uri pageUrl,
  ) {
    final links = <SourceServerLink>[];
    final seenKeys = <String>{};
    var index = 0;

    // Extract iframe src from page
    final document = html_parser.parse(html);
    final iframe = document.querySelector('iframe[src]');
    final iframeSrc = iframe?.attributes['src']?.trim();
    if (iframeSrc != null && iframeSrc.isNotEmpty) {
      final iframeUri = Uri.tryParse(
        iframeSrc.startsWith('//') ? 'https:$iframeSrc' : iframeSrc,
      );
      if (iframeUri != null &&
          iframeUri.hasScheme &&
          iframeUri.host.isNotEmpty) {
        links.add(
          SourceServerLink(
            serverId: '$index-hls',
            serverName: 'HLS',
            initialUrl: iframeUri,
            linkType: SourceServerLinkType.stream,
            detectedHost: iframeUri.host,
          ),
        );
        seenKeys.add(iframeUri.toString());
        index++;
      }
    }

    // Extract from SSR data: look for server embed URLs
    final ssrData = _extractSvelteKitData(html);
    if (ssrData != null) {
      // Look for embed URLs in SSR data
      final urlPattern = RegExp(
        r'''https?://[\w\-._~:/?#\[\]@!$&'()*+,;=%]+''',
        caseSensitive: false,
        multiLine: true,
      );
      for (final match in urlPattern.allMatches(ssrData)) {
        final raw = match.group(0)?.trim();
        if (raw == null || raw.isEmpty) {
          continue;
        }

        final uri = Uri.tryParse(raw);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          continue;
        }

        // Only include embed/player URLs, skip CDN/image/API URLs
        if (!_isEmbedUrl(uri)) {
          continue;
        }

        if (!seenKeys.add(uri.toString())) {
          continue;
        }

        final serverName = _guessServerName(uri);
        links.add(
          SourceServerLink(
            serverId: '$index-${serverName.toLowerCase().replaceAll(' ', '-')}',
            serverName: serverName,
            initialUrl: uri,
            linkType: _inferLinkTypeFromUrl(uri),
            detectedHost: uri.host,
          ),
        );
        index++;
      }
    }

    // Also look for embed URLs in raw HTML (script tags, data attributes)
    final embedPattern = RegExp(
      r'''(?:src|url|code|embed)\s*[:=]\s*['"](https?://[^'"]+)['"]''',
      caseSensitive: false,
      multiLine: true,
    );
    for (final match in embedPattern.allMatches(html)) {
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final uri = Uri.tryParse(raw);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        continue;
      }

      if (!_isEmbedUrl(uri) || !seenKeys.add(uri.toString())) {
        continue;
      }

      final serverName = _guessServerName(uri);
      links.add(
        SourceServerLink(
          serverId: '$index-${serverName.toLowerCase().replaceAll(' ', '-')}',
          serverName: serverName,
          initialUrl: uri,
          linkType: _inferLinkTypeFromUrl(uri),
          detectedHost: uri.host,
        ),
      );
      index++;
    }

    return links;
  }

  bool _isEmbedUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    // Known embed patterns
    if (path.startsWith('/e/') ||
        path.startsWith('/v/') ||
        path.startsWith('/d/') ||
        path.contains('/embed') ||
        path.contains('/player') ||
        path.contains('/m3u8/')) {
      return true;
    }

    // Known video hosting domains
    const videoHosts = <String>[
      'streamwish',
      'filemoon',
      'mp4upload',
      'mixdrop',
      'voe',
      'streamtape',
      'doodstream',
      'dood',
      'mega.nz',
      'ok.ru',
      'yourupload',
      'zilla-networks',
      'terabox',
      'pdrain',
    ];

    return videoHosts.any((videoHost) => host.contains(videoHost));
  }

  String _guessServerName(Uri uri) {
    final host = uri.host.toLowerCase();
    const hostToName = <String, String>{
      'streamwish': 'Streamwish',
      'sfastwish': 'Streamwish',
      'filemoon': 'Filemoon',
      'bysekoze': 'Filemoon',
      'mp4upload': 'Mp4Upload',
      'mixdrop': 'Mixdrop',
      'mxdrop': 'Mixdrop',
      'voe': 'VOE',
      'streamtape': 'Streamtape',
      'strtape': 'Streamtape',
      'doodstream': 'Doodstream',
      'dood': 'Doodstream',
      'mega.nz': 'Mega',
      'ok.ru': 'Okru',
      'yourupload': 'YourUpload',
      'zilla-networks': 'HLS',
      'terabox': 'TeraBox',
      'pdrain': 'PDrain',
    };

    for (final entry in hostToName.entries) {
      if (host.contains(entry.key)) {
        return entry.value;
      }
    }

    return host;
  }

  SourceServerLinkType _inferLinkTypeFromUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.contains('mega.nz') || host.contains('terabox')) {
      return SourceServerLinkType.download;
    }
    return SourceServerLinkType.stream;
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
    // /media/one-piece -> one-piece
    // /media/one-piece/1 -> one-piece
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments[0] == 'media') {
      return segments[1];
    }
    if (segments.isNotEmpty) {
      return segments.last;
    }
    return null;
  }

  double? _extractEpisodeNumberFromMediaPath(String path) {
    // /media/one-piece/220 -> 220
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
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
    if (value.contains('tv') || value.contains('anime')) {
      return AnimeFormat.tv;
    }
    if (value.contains('película') || value.contains('movie')) {
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

  AnimeFormat _mapCategoryId(Object? categoryId) {
    final id = categoryId is int
        ? categoryId
        : int.tryParse(categoryId?.toString() ?? '');
    switch (id) {
      case 1:
        return AnimeFormat.tv;
      case 2:
        return AnimeFormat.movie;
      case 3:
        return AnimeFormat.ova;
      case 4:
        return AnimeFormat.ona;
      case 5:
        return AnimeFormat.special;
      default:
        return AnimeFormat.unknown;
    }
  }

  Uri? _asCdnUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.startsWith('http')) {
      return Uri.tryParse(trimmed);
    }
    if (trimmed.startsWith('//')) {
      return Uri.tryParse('https:$trimmed');
    }
    if (trimmed.startsWith('/')) {
      return Uri.tryParse('https://cdn.animeav1.com$trimmed');
    }
    return Uri.tryParse(trimmed);
  }

  String _formatNumber(double number) {
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
  }
}
