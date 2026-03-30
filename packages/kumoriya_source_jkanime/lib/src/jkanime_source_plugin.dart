import 'dart:convert';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'errors/jkanime_error.dart';

final _whitespaceRe = RegExp(r'\s+');
final _trailingParenRe = RegExp(r'\s*\([^)]*\)\s*$');
final _multiDashRe = RegExp(r'-+');
final _leadTrailDashRe = RegExp(r'^-|-$');
final _yearRe = RegExp(r'(19|20)\d{2}');
final _trailingIntRe = RegExp(r'(\d+)(?!.*\d)');
final _seasonDescriptorPatterns = <RegExp>[
  RegExp(r'\s*[-:]?\s*\b\d+(?:st|nd|rd|th)?\s+season\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\bseason\s+\d+\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\bpart\s+\d+\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\bcour\s+\d+\b$', caseSensitive: false),
  RegExp(r'\s*[-:]?\s*\b(?:ii|iii|iv|v)\b$', caseSensitive: false),
];
final _videoAssignmentRe = RegExp(
  r"""video\s*\[\s*['"]?(\d+)['"]?\s*\]\s*=\s*(['"])([\s\S]*?)\2\s*;""",
  multiLine: true,
);
final _iframeSrcRe = RegExp(
  r"""src\s*=\s*(?:"([^"]+)"|'([^']+)'|([^"'\s>]+))""",
  caseSensitive: false,
  multiLine: true,
);

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
    KumoriyaError? lastError;

    for (final candidateQuery in _buildSearchFallbacks(query.query)) {
      final path = 'buscar/${Uri.encodeComponent(candidateQuery)}/';
      final htmlResult = await _fetchHtml(path);

      final parsedResult = htmlResult
          .fold<Result<List<SourceAnimeMatch>, KumoriyaError>>(
            onFailure: (error) {
              lastError = error;
              return Failure(error);
            },
            onSuccess: (html) {
              try {
                return Success(_parseSearchMatches(html, limit: query.limit));
              } catch (error) {
                final parseError = JkAnimeParseError(
                  message: 'Failed to parse JKAnime search: $error',
                );
                lastError = parseError;
                return Failure(parseError);
              }
            },
          );

      if (!parsedResult.isSuccess) {
        continue;
      }

      final matches = parsedResult.fold(
        onFailure: (_) => const <SourceAnimeMatch>[],
        onSuccess: (items) => items,
      );
      if (matches.isNotEmpty) {
        return Success(matches);
      }
    }

    if (lastError != null) {
      return Failure(lastError!);
    }

    return const Success(<SourceAnimeMatch>[]);
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
          final fallbackOgTitle = document
              .querySelector('meta[property="og:title"]')
              ?.attributes['content']
              ?.trim();
          final resolvedTitle = title.isNotEmpty
              ? title
              : _extractTitleFromOgTitle(fallbackOgTitle);

          if (resolvedTitle.isEmpty) {
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
              title: resolvedTitle,
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
        } on JkAnimeError catch (error) {
          return Failure(error);
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
      final response = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return Failure(
          JkAnimeTransportError(
            message:
                'JKAnime request failed with status ${response.statusCode}',
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
      final streamed = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 15));
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
      final response = await _httpClient
          .post(
            uri,
            headers: <String, String>{
              'X-CSRF-TOKEN': context.csrfToken,
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': _baseUri.resolve('${context.slug}/').toString(),
              if (context.cookieHeader != null) 'Cookie': context.cookieHeader!,
            },
            body: <String, String>{'_token': context.csrfToken},
          )
          .timeout(const Duration(seconds: 15));

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

      final episodeNumber = _parseEpisodeNumber(number);
      if (id is! int ||
          episodeNumber == null ||
          title is! String ||
          title.trim().isEmpty) {
        continue;
      }

      final image = item['image'];
      episodes.add(
        SourceEpisode(
          sourceEpisodeId: id.toString(),
          number: episodeNumber,
          title: title.trim(),
          episodeUrl: _baseUri.resolve(
            '$slug/${_episodeNumberPathSegment(episodeNumber)}/',
          ),
          thumbnailUrl: image is String && image.startsWith('http')
              ? Uri.parse(image)
              : null,
        ),
      );
    }

    final dedupedById = <String, SourceEpisode>{};
    for (final episode in episodes) {
      dedupedById[episode.sourceEpisodeId] = episode;
    }

    return dedupedById.values.toList(growable: false);
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
    add(_slugify(query));
    add(_slugify(withoutSeason));

    return ordered;
  }

  List<SourceAnimeMatch> _parseSearchMatches(
    String html, {
    required int limit,
  }) {
    final document = html_parser.parse(html);
    final cards = document.querySelectorAll('.page_directorio .anime__item');
    final matches = <SourceAnimeMatch>[];
    final seenSourceIds = <String>{};

    for (final card in cards) {
      final title = card.querySelector('h5 a')?.text.trim() ?? '';
      final href = card.querySelector('h5 a')?.attributes['href'] ?? '';
      final sourceId = _extractSourceIdFromUrl(href);
      if (title.isEmpty ||
          sourceId == null ||
          seenSourceIds.contains(sourceId)) {
        continue;
      }
      seenSourceIds.add(sourceId);

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

      if (matches.length >= limit) {
        break;
      }
    }

    return matches;
  }

  String? _extractSourceIdFromUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return null;
    }

    final resolved = uri.hasScheme ? uri : _baseUri.resolveUri(uri);
    if (resolved.host.isNotEmpty &&
        !resolved.host.toLowerCase().endsWith('jkanime.net')) {
      return null;
    }

    final segments = resolved.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return null;
    }

    return segments.first;
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

  String _extractTitleFromOgTitle(String? ogTitle) {
    if (ogTitle == null || ogTitle.isEmpty) {
      return '';
    }

    final delimiter = ' Sub ';
    final delimiterIndex = ogTitle.indexOf(delimiter);
    final title = delimiterIndex == -1
        ? ogTitle
        : ogTitle.substring(0, delimiterIndex);
    return title.trim();
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
    final match = _yearRe.firstMatch(text);
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

      final isCollapsedSeparator =
          codeUnit == 47 ||
          codeUnit == 92 ||
          codeUnit == 39 ||
          codeUnit == 8217;
      if (isCollapsedSeparator) {
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

  List<SourceServerLink> _extractServerLinksFromEpisodeHtml(String html) {
    final document = html_parser.parse(html);
    final serverButtons = document.querySelectorAll('.servers');
    final videoByIndex = _extractVideoTargetsByIndex(html);
    final dynamicByServerLabel = _extractDynamicServerTargetsByLabel(html);

    final streamLinks = <SourceServerLink>[];
    var parseableButtonCount = 0;
    final seenKeys = <String>{};
    final consumedDynamicLabels = <String>{};

    for (final button in serverButtons) {
      final serverName = button.text.trim();
      if (serverName.isEmpty) {
        continue;
      }

      final index = _extractServerIndex(
        dataIdAttr: button.attributes['data-id'],
        elementIdAttr: button.attributes['id'],
        href: button.attributes['href'],
      );
      if (index == null) {
        continue;
      }
      parseableButtonCount++;

      _ExtractedServerTarget? target = videoByIndex[index];
      String? dynamicLanguage;
      final normalizedServerLabel = _normalizeServerLabel(serverName);
      consumedDynamicLabels.add(normalizedServerLabel);
      if (target == null) {
        final dynamicEntry = dynamicByServerLabel[normalizedServerLabel];
        if (dynamicEntry != null) {
          target = dynamicEntry.target;
          dynamicLanguage = dynamicEntry.language;
        }
      }
      if (target == null) {
        continue;
      }
      final normalizedServerSlug = serverName.toLowerCase().replaceAll(
        ' ',
        '-',
      );
      final serverId = '$index-$normalizedServerSlug';
      final dedupeKey = '${target.url}|$normalizedServerSlug|stream';
      if (!seenKeys.add(dedupeKey)) {
        continue;
      }

      streamLinks.add(
        SourceServerLink(
          serverId: serverId,
          serverName: serverName,
          initialUrl: target.url,
          language:
              _extractLanguageFromClasses(button.classes) ?? dynamicLanguage,
          linkType: SourceServerLinkType.stream,
          detectedHost: target.detectedHost ?? target.url.host,
        ),
      );
    }

    if (serverButtons.isNotEmpty && streamLinks.isEmpty) {
      final hasVideoAssignments = RegExp(
        r'''video\s*\[\s*['"]?\d+['"]?\s*\]''',
        multiLine: true,
      ).hasMatch(html);

      if (parseableButtonCount == 0) {
        throw const JkAnimeParseError(
          message:
              'JKAnime server buttons were found but no parseable server index was detected.',
        );
      }

      if (!hasVideoAssignments) {
        throw JkAnimeInconsistentPayloadError(
          message:
              'JKAnime server buttons are present ($parseableButtonCount), but no video[index] assignments exist in payload.',
        );
      }

      if (videoByIndex.isEmpty) {
        throw const JkAnimeParseError(
          message:
              'JKAnime video[index] assignments were detected but no valid iframe/url could be extracted.',
        );
      }

      throw JkAnimeInconsistentPayloadError(
        message:
            'JKAnime server mapping failed: $parseableButtonCount parseable buttons, ${videoByIndex.length} extracted video entries, 0 resolved links.',
      );
    }

    final downloadLinks = _extractDownloadLinks(document, seenKeys: seenKeys);
    final dynamicSupplementalLinks = _extractSupplementalDynamicLinks(
      dynamicByServerLabel: dynamicByServerLabel,
      consumedLabels: consumedDynamicLabels,
      seenKeys: seenKeys,
    );

    return <SourceServerLink>[
      ...streamLinks,
      ...dynamicSupplementalLinks,
      ...downloadLinks,
    ];
  }

  double? _parseEpisodeNumber(Object? rawNumber) {
    if (rawNumber is num) {
      return rawNumber.toDouble();
    }
    if (rawNumber is String) {
      return double.tryParse(rawNumber.trim());
    }
    return null;
  }

  Map<int, _ExtractedServerTarget> _extractVideoTargetsByIndex(String html) {
    final byIndex = <int, _ExtractedServerTarget>{};

    for (final match in _videoAssignmentRe.allMatches(html)) {
      final rawIndex = match.group(1);
      final rawValue = match.group(3);
      if (rawIndex == null || rawValue == null) {
        continue;
      }

      final index = int.tryParse(rawIndex);
      if (index == null) {
        continue;
      }

      final target = _extractVideoTarget(rawValue);
      if (target != null) {
        byIndex[index] = target;
      }
    }

    return byIndex;
  }

  _ExtractedServerTarget? _extractVideoTarget(String rawValue) {
    final normalized = rawValue
        .replaceAll(r'\/', '/')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'");

    final direct = _normalizePotentialVideoTarget(normalized.trim());
    if (direct != null) {
      return direct;
    }

    final srcMatch = _iframeSrcRe.firstMatch(normalized);
    if (srcMatch == null) {
      return null;
    }

    final rawSrc =
        srcMatch.group(1) ?? srcMatch.group(2) ?? srcMatch.group(3) ?? '';
    return _normalizePotentialVideoTarget(rawSrc.trim());
  }

  _ExtractedServerTarget? _normalizePotentialVideoTarget(String raw) {
    if (raw.isEmpty) {
      return null;
    }

    final candidate = raw.startsWith('//') ? 'https:$raw' : raw;
    final parsed = Uri.tryParse(candidate);
    if (parsed == null) {
      return null;
    }
    if (!parsed.hasScheme) {
      return null;
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return null;
    }
    if (parsed.host.isEmpty) {
      return null;
    }

    final resolved = _resolveWrappedVideoUrl(parsed);
    if (resolved == null) {
      return _ExtractedServerTarget(url: parsed);
    }

    final resolvedHost = _extractServerAliasHost(parsed);
    return _ExtractedServerTarget(
      url: resolved,
      originalWrapperUrl: parsed,
      detectedHost: resolvedHost ?? resolved.host,
    );
  }

  Uri? _resolveWrappedVideoUrl(Uri sourceUri) {
    final normalizedPath = sourceUri.path.toLowerCase();
    final isC1Wrapper =
        normalizedPath == '/jkplayer/c1' || normalizedPath == '/jkplayer/c2';
    if (!isC1Wrapper) {
      return null;
    }

    final encoded = sourceUri.queryParameters['u'];
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      final normalized = base64.normalize(encoded.trim());
      final decoded = utf8.decode(base64.decode(normalized));
      final parsed = Uri.tryParse(decoded.trim());
      if (parsed == null ||
          !parsed.hasScheme ||
          parsed.host.isEmpty ||
          (parsed.scheme != 'http' && parsed.scheme != 'https')) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  String? _extractServerAliasHost(Uri sourceUri) {
    final alias = sourceUri.queryParameters['s']?.trim().toLowerCase();
    if (alias == null || alias.isEmpty) {
      return null;
    }

    const aliasToHost = <String, String>{
      'voe': 'voe.sx',
      'streamwish': 'streamwish.to',
      'filemoon': 'filemoon.sx',
      'mixdrop': 'mixdrop.co',
      'mp4upload': 'mp4upload.com',
      'vidhide': 'vidhide.com',
      'streamtape': 'streamtape.com',
      'mega': 'mega.nz',
      'mediafire': 'mediafire.com',
    };

    return aliasToHost[alias];
  }

  List<SourceServerLink> _extractDownloadLinks(
    html_dom.Document document, {
    required Set<String> seenKeys,
  }) {
    final rows = document.querySelectorAll('.download table tr');
    if (rows.isEmpty) {
      return const <SourceServerLink>[];
    }

    final links = <SourceServerLink>[];
    var downloadIndex = 0;

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 4) {
        continue;
      }

      final label = cells.first.text.trim();
      final linkEl = row.querySelector('a[href]');
      if (label.isEmpty || linkEl == null) {
        continue;
      }

      final href = linkEl.attributes['href']?.trim();
      if (href == null || href.isEmpty) {
        continue;
      }

      final parsed = _normalizePotentialVideoTarget(href);
      final url = parsed?.url ?? _asUri(href);
      if (url == null) {
        continue;
      }

      final slug = label.toLowerCase().replaceAll(' ', '-');
      final dedupeKey = '$slug|download';
      if (!seenKeys.add(dedupeKey)) {
        continue;
      }

      final hostByLabel = _guessHostFromLabel(label);
      links.add(
        SourceServerLink(
          serverId: 'download-$downloadIndex-$slug',
          serverName: label,
          initialUrl: url,
          linkType: SourceServerLinkType.download,
          detectedHost: hostByLabel ?? parsed?.detectedHost ?? url.host,
        ),
      );
      downloadIndex++;
    }

    return links;
  }

  Map<String, _DynamicServerEntry> _extractDynamicServerTargetsByLabel(
    String html,
  ) {
    final match = RegExp(
      r'''var\s+servers\s*=\s*(\[[\s\S]*?\]);''',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(html);
    if (match == null) {
      return const <String, _DynamicServerEntry>{};
    }

    final rawServers = match.group(1);
    if (rawServers == null || rawServers.trim().isEmpty) {
      return const <String, _DynamicServerEntry>{};
    }

    final byLabel = <String, _DynamicServerEntry>{};
    try {
      final decoded = jsonDecode(rawServers);
      if (decoded is! List) {
        return const <String, _DynamicServerEntry>{};
      }

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final serverName = item['server'] is String
            ? (item['server'] as String).trim()
            : '';
        if (serverName.isEmpty) {
          continue;
        }

        final remoteEncoded = item['remote'] is String
            ? (item['remote'] as String).trim()
            : '';
        final decodedRemote = _decodeDynamicRemoteUrl(remoteEncoded);
        if (decodedRemote == null) {
          continue;
        }

        final target = _normalizePotentialVideoTarget(decodedRemote);
        if (target == null) {
          continue;
        }

        final normalizedLabel = _normalizeServerLabel(serverName);
        if (normalizedLabel.isEmpty || byLabel.containsKey(normalizedLabel)) {
          continue;
        }

        byLabel[normalizedLabel] = _DynamicServerEntry(
          serverName: serverName,
          normalizedServerLabel: normalizedLabel,
          target: target,
          language: _mapDynamicLanguage(item['lang']),
          linkTypeHint: _inferDynamicLinkType(serverName, target.url),
        );
      }
    } catch (_) {
      return const <String, _DynamicServerEntry>{};
    }

    return byLabel;
  }

  String? _decodeDynamicRemoteUrl(String encoded) {
    if (encoded.trim().isEmpty) {
      return null;
    }

    try {
      final normalized = base64.normalize(encoded.trim());
      final decoded = utf8.decode(base64.decode(normalized)).trim();
      if (decoded.isEmpty) {
        return null;
      }
      if (decoded.startsWith('//')) {
        return 'https:$decoded';
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  List<SourceServerLink> _extractSupplementalDynamicLinks({
    required Map<String, _DynamicServerEntry> dynamicByServerLabel,
    required Set<String> consumedLabels,
    required Set<String> seenKeys,
  }) {
    if (dynamicByServerLabel.isEmpty) {
      return const <SourceServerLink>[];
    }

    final links = <SourceServerLink>[];
    for (final entry in dynamicByServerLabel.values) {
      if (consumedLabels.contains(entry.normalizedServerLabel)) {
        continue;
      }
      final serverSlug = entry.normalizedServerLabel.replaceAll(' ', '-');
      final serverId = 'dynamic-$serverSlug';
      final dedupeKey = entry.linkTypeHint == SourceServerLinkType.download
          ? '$serverSlug|download'
          : '${entry.target.url.toString()}|$serverSlug|stream';
      if (!seenKeys.add(dedupeKey)) {
        continue;
      }

      links.add(
        SourceServerLink(
          serverId: serverId,
          serverName: entry.serverName,
          initialUrl: entry.target.url,
          language: entry.language,
          linkType: entry.linkTypeHint,
          detectedHost: entry.target.detectedHost ?? entry.target.url.host,
        ),
      );
    }

    return links;
  }

  String _normalizeServerLabel(String value) {
    return value.trim().toLowerCase().replaceAll(_whitespaceRe, ' ');
  }

  String? _mapDynamicLanguage(Object? raw) {
    final asInt = switch (raw) {
      int value => value,
      String value => int.tryParse(value.trim()),
      _ => null,
    };

    switch (asInt) {
      case 1:
        return 'sub';
      case 2:
        return 'lat';
      case 3:
        return 'cast';
    }
    return null;
  }

  SourceServerLinkType _inferDynamicLinkType(String serverName, Uri url) {
    final serverValue = serverName.trim().toLowerCase();
    if (serverValue == 'mediafire') {
      return SourceServerLinkType.download;
    }

    final host = url.host.toLowerCase();
    if (host.contains('mediafire.com')) {
      return SourceServerLinkType.download;
    }

    return SourceServerLinkType.stream;
  }

  String? _guessHostFromLabel(String label) {
    final value = label.trim().toLowerCase();
    if (value.isEmpty) {
      return null;
    }

    const byLabel = <String, String>{
      'mediafire': 'mediafire.com',
      'mega': 'mega.nz',
      'streamwish': 'streamwish.to',
      'voe': 'voe.sx',
      'vidhide': 'vidhide.com',
      'filemoon': 'filemoon.sx',
      'mixdrop': 'mixdrop.co',
      'mp4upload': 'mp4upload.com',
      'streamtape': 'streamtape.com',
    };

    return byLabel[value];
  }

  int? _extractServerIndex({
    String? dataIdAttr,
    String? elementIdAttr,
    String? href,
  }) {
    final candidates = <String?>[dataIdAttr, elementIdAttr, href];
    for (final candidate in candidates) {
      final parsed = _extractTrailingInt(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  int? _extractTrailingInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final trimmed = raw.trim();
    final exact = int.tryParse(trimmed);
    if (exact != null) {
      return exact;
    }

    final match = _trailingIntRe.firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1)!);
  }

  String? _extractLanguageFromClasses(Set<String> classes) {
    if (classes.isEmpty) {
      return null;
    }

    final lowerClasses = classes.map((value) => value.toLowerCase()).toSet();
    if (lowerClasses.contains('lg_1') ||
        lowerClasses.contains('lang-sub') ||
        lowerClasses.contains('sub')) {
      return 'sub';
    }
    if (lowerClasses.contains('lg_2') ||
        lowerClasses.contains('lang-lat') ||
        lowerClasses.contains('latino') ||
        lowerClasses.contains('audio-latino')) {
      return 'lat';
    }
    if (lowerClasses.contains('lg_3') ||
        lowerClasses.contains('lang-cast') ||
        lowerClasses.contains('castellano')) {
      return 'cast';
    }

    return null;
  }

  String _episodeNumberPathSegment(double number) {
    return number == number.truncateToDouble()
        ? number.toInt().toString()
        : number.toString();
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

final class _ExtractedServerTarget {
  const _ExtractedServerTarget({
    required this.url,
    this.originalWrapperUrl,
    this.detectedHost,
  });

  final Uri url;
  final Uri? originalWrapperUrl;
  final String? detectedHost;
}

final class _DynamicServerEntry {
  const _DynamicServerEntry({
    required this.serverName,
    required this.normalizedServerLabel,
    required this.target,
    required this.language,
    required this.linkTypeHint,
  });

  final String serverName;
  final String normalizedServerLabel;
  final _ExtractedServerTarget target;
  final String? language;
  final SourceServerLinkType linkTypeHint;
}
