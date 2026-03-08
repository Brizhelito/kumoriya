import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/jkanime_error.dart';

final class JkAnimeSourcePlugin implements SourcePlugin {
  JkAnimeSourcePlugin({http.Client? httpClient, Uri? baseUri})
    : _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://jkanime.net/');

  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.jkanime',
    displayName: 'JKAnime',
    type: PluginType.source,
    iconUrl: 'https://cdn.jkdesa.com/assets3/css/img/jkanimenet.png?v=2.0.180',
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.animeDetail,
      PluginCapability.episodeList,
    },
    baseUrls: <String>['https://jkanime.net'],
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    final path = 'buscar/${Uri.encodeComponent(query.query.trim())}/';
    final htmlResult = await _fetchHtml(path);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final document = html_parser.parse(html);
          final cards = document.querySelectorAll(
            '.page_directorio .anime__item',
          );
          final matches = <SourceAnimeMatch>[];

          for (final card in cards) {
            final title = card.querySelector('h5 a')?.text.trim() ?? '';
            final href = card.querySelector('h5 a')?.attributes['href'] ?? '';
            final sourceId = _extractSourceIdFromUrl(href);
            if (title.isEmpty || sourceId == null) {
              continue;
            }

            final imageUrl = card
                .querySelector('.anime__item__pic')
                ?.attributes['data-setbg']
                ?.trim();

            final rawFormat = card.querySelector('li.anime')?.text.trim();
            matches.add(
              SourceAnimeMatch(
                sourceId: sourceId,
                title: title,
                thumbnailUrl: _asUri(imageUrl),
                format: _mapFormat(rawFormat),
              ),
            );

            if (matches.length >= query.limit) {
              break;
            }
          }

          return Success(matches);
        } catch (error) {
          return Failure(
            JkAnimeParseError(
              message: 'Failed to parse JKAnime search: $error',
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
    final htmlResult = await _fetchHtml('$slug/');

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final document = html_parser.parse(html);
          final title =
              document.querySelector('.anime_info h3')?.text.trim() ?? '';
          if (title.isEmpty) {
            return const Failure(
              JkAnimeParseError(message: 'JKAnime detail title was not found.'),
            );
          }

          final synopsis = document
              .querySelector('.anime_info p.scroll')
              ?.text
              .trim();
          final thumbnail = document
              .querySelector('.anime_pic img')
              ?.attributes['src'];
          final typeText = document
              .querySelector('.anime_data li[rel="tipo"]')
              ?.text
              .trim();
          final emittedText = document
              .querySelectorAll('.anime_data li')
              .map((node) => node.text.trim())
              .firstWhere(
                (text) => text.toLowerCase().contains('emitido'),
                orElse: () => '',
              );

          return Success(
            SourceAnimeDetail(
              sourceId: slug,
              title: title,
              synopsis: synopsis?.isEmpty == true ? null : synopsis,
              thumbnailUrl: _asUri(thumbnail),
              releaseYear: _extractYear(emittedText),
              format: _mapFormat(typeText),
            ),
          );
        } catch (error) {
          return Failure(
            JkAnimeParseError(
              message: 'Failed to parse JKAnime detail: $error',
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
    final detailResult = await _fetchDetailPageContext(slug);

    return detailResult.fold(
      onFailure: Failure.new,
      onSuccess: (context) async {
        final allEpisodes = <SourceEpisode>[];
        final firstPageResult = await _fetchEpisodePage(
          context: context,
          page: 1,
        );

        if (firstPageResult is Failure<Map<String, dynamic>, KumoriyaError>) {
          return Failure(firstPageResult.error);
        }

        final firstPage =
            (firstPageResult as Success<Map<String, dynamic>, KumoriyaError>)
                .value;
        allEpisodes.addAll(_parseEpisodesFromPayload(firstPage, slug: slug));

        final lastPage = firstPage['last_page'] is int
            ? firstPage['last_page'] as int
            : 1;

        for (var page = 2; page <= lastPage; page++) {
          final pageResult = await _fetchEpisodePage(
            context: context,
            page: page,
          );
          if (pageResult is Failure<Map<String, dynamic>, KumoriyaError>) {
            return Failure(pageResult.error);
          }

          final payload =
              (pageResult as Success<Map<String, dynamic>, KumoriyaError>)
                  .value;
          allEpisodes.addAll(_parseEpisodesFromPayload(payload, slug: slug));
        }

        if (allEpisodes.isEmpty) {
          return const Failure(
            JkAnimeSourceEmptyError(
              message: 'JKAnime returned no episodes for this anime.',
            ),
          );
        }

        allEpisodes.sort((a, b) => a.number.compareTo(b.number));
        return Success(allEpisodes);
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
    final htmlResult = await _fetchHtml(episodePath);

    return htmlResult.fold(
      onFailure: Failure.new,
      onSuccess: (html) {
        try {
          final links = _extractServerLinksFromEpisodeHtml(html);
          return Success(links);
        } catch (error) {
          return Failure(
            JkAnimeParseError(
              message: 'Failed to parse JKAnime episode server links: $error',
            ),
          );
        }
      },
    );
  }

  Future<Result<String, KumoriyaError>> _fetchHtml(String path) async {
    final uri = _baseUri.resolve(path);
    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) {
        return Failure(
          JkAnimeTransportError(
            message:
                'JKAnime request failed with status ${response.statusCode}.',
          ),
        );
      }

      return Success(response.body);
    } catch (error) {
      return Failure(
        JkAnimeTransportError(message: 'JKAnime request failed: $error'),
      );
    }
  }

  Future<Result<_DetailPageContext, KumoriyaError>> _fetchDetailPageContext(
    String slug,
  ) async {
    final uri = _baseUri.resolve('$slug/');

    try {
      final request = http.Request('GET', uri);
      final streamed = await _httpClient.send(request);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        return Failure(
          JkAnimeTransportError(
            message:
                'JKAnime detail request failed with status ${streamed.statusCode}.',
          ),
        );
      }

      final document = html_parser.parse(body);
      final csrfToken = document
          .querySelector('meta[name="csrf-token"]')
          ?.attributes['content']
          ?.trim();
      final animeNumericId = document
          .querySelector('#guardar-anime')
          ?.attributes['data-anime']
          ?.trim();
      final setCookieHeader = streamed.headers['set-cookie'];

      if (csrfToken == null ||
          csrfToken.isEmpty ||
          animeNumericId == null ||
          animeNumericId.isEmpty) {
        return const Failure(
          JkAnimeParseError(
            message: 'JKAnime detail page is missing csrf token or anime id.',
          ),
        );
      }

      return Success(
        _DetailPageContext(
          slug: slug,
          csrfToken: csrfToken,
          animeNumericId: animeNumericId,
          cookieHeader: _normalizeCookieHeader(setCookieHeader),
        ),
      );
    } catch (error) {
      return Failure(
        JkAnimeTransportError(
          message: 'Failed to load JKAnime detail context: $error',
        ),
      );
    }
  }

  Future<Result<Map<String, dynamic>, KumoriyaError>> _fetchEpisodePage({
    required _DetailPageContext context,
    required int page,
  }) async {
    final uri = _baseUri.resolve(
      'ajax/episodes/${context.animeNumericId}/$page',
    );

    try {
      final response = await _httpClient.post(
        uri,
        headers: <String, String>{
          'X-CSRF-TOKEN': context.csrfToken,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': _baseUri.resolve('${context.slug}/').toString(),
          if (context.cookieHeader != null) 'Cookie': context.cookieHeader!,
        },
        body: <String, String>{'_token': context.csrfToken},
      );

      if (response.statusCode != 200) {
        return Failure(
          JkAnimeTransportError(
            message:
                'JKAnime episodes request failed with status ${response.statusCode}.',
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const Failure(
          JkAnimeParseError(
            message: 'JKAnime episodes payload is not an object.',
          ),
        );
      }

      return Success(decoded);
    } catch (error) {
      return Failure(
        JkAnimeTransportError(
          message: 'Failed to request JKAnime episodes: $error',
        ),
      );
    }
  }

  List<SourceEpisode> _parseEpisodesFromPayload(
    Map<String, dynamic> payload, {
    required String slug,
  }) {
    final data = payload['data'];
    if (data is! List) {
      return const <SourceEpisode>[];
    }

    final episodes = <SourceEpisode>[];

    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final id = item['id'];
      final number = item['number'];
      final title = item['title'];

      if (id is! int ||
          number is! num ||
          title is! String ||
          title.trim().isEmpty) {
        continue;
      }

      final image = item['image'];
      final episodeNumber = number.toDouble();
      episodes.add(
        SourceEpisode(
          sourceEpisodeId: id.toString(),
          number: episodeNumber,
          title: title.trim(),
          episodeUrl: _baseUri.resolve('$slug/${number.toString()}/'),
          thumbnailUrl: image is String && image.startsWith('http')
              ? Uri.parse(image)
              : null,
        ),
      );
    }

    return episodes;
  }

  String _normalizeSourceId(String sourceId) {
    final trimmed = sourceId.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.first;
      }
    }

    return trimmed.replaceAll('/', '');
  }

  String? _extractSourceIdFromUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return null;
    }

    return segments.first;
  }

  AnimeFormat _mapFormat(String? raw) {
    if (raw == null) {
      return AnimeFormat.unknown;
    }

    final value = raw.toLowerCase();
    if (value.contains('serie')) {
      return AnimeFormat.tv;
    }
    if (value.contains('pelicula')) {
      return AnimeFormat.movie;
    }
    if (value.contains('ova')) {
      return AnimeFormat.ova;
    }
    if (value.contains('especial')) {
      return AnimeFormat.special;
    }

    return AnimeFormat.unknown;
  }

  int? _extractYear(String text) {
    final match = RegExp(r'(19|20)\d{2}').firstMatch(text);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(0)!);
  }

  String? _normalizeCookieHeader(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.trim().isEmpty) {
      return null;
    }

    final segments = setCookieHeader.split(',');
    final cookies = <String>[];

    for (final segment in segments) {
      final parts = segment.split(';');
      if (parts.isEmpty) {
        continue;
      }

      final first = parts.first.trim();
      if (first.contains('=')) {
        cookies.add(first);
      }
    }

    if (cookies.isEmpty) {
      return null;
    }

    return cookies.join('; ');
  }

  Uri? _asUri(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    return Uri.tryParse(raw.trim());
  }

  List<SourceServerLink> _extractServerLinksFromEpisodeHtml(String html) {
    final document = html_parser.parse(html);
    final serverButtons = document.querySelectorAll('.bg-servers .servers');

    final videoPattern = RegExp(
      r'''video\[(\d+)\]\s*=\s*'<iframe[^>]*src="([^"]+)"''',
      multiLine: true,
    );
    final videoByIndex = <int, Uri>{};

    for (final match in videoPattern.allMatches(html)) {
      final rawIndex = match.group(1);
      final rawUrl = match.group(2);
      if (rawIndex == null || rawUrl == null) {
        continue;
      }

      final index = int.tryParse(rawIndex);
      final uri = Uri.tryParse(rawUrl);
      if (index == null || uri == null) {
        continue;
      }

      videoByIndex[index] = uri;
    }

    if (serverButtons.isEmpty) {
      return const <SourceServerLink>[];
    }

    final links = <SourceServerLink>[];
    for (final button in serverButtons) {
      final idAttr = button.attributes['data-id']?.trim();
      final serverName = button.text.trim();
      if (idAttr == null || serverName.isEmpty) {
        continue;
      }

      final index = int.tryParse(idAttr);
      if (index == null) {
        continue;
      }

      final initialUrl = videoByIndex[index];
      if (initialUrl == null) {
        continue;
      }

      final classes = button.classes;
      final languageClass = classes
          .where((value) => value.startsWith('lg_'))
          .firstWhere((_) => true, orElse: () => '');

      final language = switch (languageClass) {
        'lg_1' => 'sub',
        'lg_2' => 'lat',
        'lg_3' => 'cast',
        _ => null,
      };

      links.add(
        SourceServerLink(
          serverId: '$index-${serverName.toLowerCase().replaceAll(' ', '-')}',
          serverName: serverName,
          initialUrl: initialUrl,
          language: language,
        ),
      );
    }

    if (serverButtons.isNotEmpty && links.isEmpty) {
      throw const JkAnimeParseError(
        message: 'JKAnime server buttons were found but link mapping failed.',
      );
    }

    return links;
  }
}

final class _DetailPageContext {
  const _DetailPageContext({
    required this.slug,
    required this.csrfToken,
    required this.animeNumericId,
    required this.cookieHeader,
  });

  final String slug;
  final String csrfToken;
  final String animeNumericId;
  final String? cookieHeader;
}
