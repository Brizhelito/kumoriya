import 'dart:convert';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'miruro_client.dart';

const List<String> _preferredProviders = <String>[
  'kiwi',
  'zoro',
  'arc',
  'pewe',
  'bee',
  'bonk',
  'moo',
  'ally',
  'hop',
  'jet',
];

const List<String> _preferredCategories = <String>['sub', 'dub'];

class MiruroSourcePlugin implements SourcePlugin {
  final AnilistMetadataGateway _anilistGateway;
  final MiruroClient _client;

  MiruroSourcePlugin({
    AnilistMetadataGateway? anilistGateway,
    MiruroClient? client,
  }) : _anilistGateway =
           anilistGateway ??
           GraphqlAnilistMetadataGateway(client: HttpAnilistGraphqlClient()),
       _client = client ?? MiruroClient();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.source.miruro',
    displayName: 'Miruro (EN)',
    type: PluginType.source,
    capabilities: {
      PluginCapability.search,
      PluginCapability.animeDetail,
      PluginCapability.episodeList,
      PluginCapability.linkExtraction,
    },
    supportedHosts: <String>['miruro.tv', 'www.miruro.tv'],
    baseUrls: <String>[
      'https://www.miruro.tv/info/',
      'https://www.miruro.tv/watch/',
    ],
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    final result = await _anilistGateway.searchAnime(
      query: query.query,
      page: query.page,
      perPage: query.limit,
    );

    return result.fold(
      onSuccess: (data) {
        final matches = data.map((item) {
          final title =
              item['title']?['english'] ??
              item['title']?['romaji'] ??
              'Unknown';
          final coverImage = item['coverImage']?['large'];

          return SourceAnimeMatch(
            sourceId: item['id'].toString(),
            title: title,
            thumbnailUrl: coverImage != null ? Uri.tryParse(coverImage) : null,
            releaseYear: item['seasonYear'],
            totalEpisodes: item['episodes'],
          );
        }).toList();
        return Success(matches);
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    final anilistId = int.tryParse(sourceId);
    if (anilistId == null) {
      return const Failure(
        SimpleError(code: 'INVALID_ID', message: 'Invalid AniList ID'),
      );
    }

    final result = await _anilistGateway.fetchAnimeDetail(anilistId);

    return result.fold(
      onSuccess: (item) {
        final title =
            item['title']?['english'] ?? item['title']?['romaji'] ?? 'Unknown';
        final coverImage = item['coverImage']?['large'];

        return Success(
          SourceAnimeDetail(
            sourceId: item['id'].toString(),
            title: title,
            synopsis: item['description'],
            thumbnailUrl: coverImage != null ? Uri.tryParse(coverImage) : null,
            releaseYear: item['seasonYear'],
            totalEpisodes: item['episodes'],
          ),
        );
      },
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    try {
      final response = await _client.pipeRequest(
        'episodes',
        query: {'anilistId': sourceId},
      );

      if (!response.containsKey('providers')) {
        return const Success([]);
      }

      final providers = response['providers'] as Map<String, dynamic>;
      final episodesByNumber = <double, _MiruroEpisodeAccumulator>{};

      for (final provider in _orderedProviderKeys(providers)) {
        final providerData = providers[provider];
        if (providerData is! Map<String, dynamic>) {
          continue;
        }
        final episodesData =
            providerData['episodes'] as Map<String, dynamic>? ?? {};

        for (final category in _orderedCategoryKeys(episodesData)) {
          final rawEpisodes = episodesData[category];
          if (rawEpisodes is! List) {
            continue;
          }

          for (final rawEpisode in rawEpisodes) {
            if (rawEpisode is! Map<String, dynamic>) {
              continue;
            }
            final numberValue = rawEpisode['number'];
            if (numberValue is! num) {
              continue;
            }
            final episodeId = rawEpisode['id']?.toString().trim();
            if (episodeId == null || episodeId.isEmpty) {
              continue;
            }

            final number = numberValue.toDouble();
            final accumulator = episodesByNumber.putIfAbsent(
              number,
              () => _MiruroEpisodeAccumulator(
                anilistId: sourceId,
                number: number,
              ),
            );
            accumulator.addVariant(
              provider: provider,
              category: category,
              episodeId: episodeId,
              rawEpisode: rawEpisode,
            );
          }
        }
      }

      final episodes =
          episodesByNumber.values
              .where((episode) => episode.hasVariants)
              .map((episode) => episode.toSourceEpisode())
              .toList(growable: false)
            ..sort((left, right) => left.number.compareTo(right.number));

      return Success(episodes);
    } catch (e) {
      return Failure(
        SimpleError(code: 'EPISODES_ERROR', message: e.toString()),
      );
    }
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    try {
      final epData =
          jsonDecode(episode.sourceEpisodeId) as Map<String, dynamic>;
      final links = <SourceServerLink>[];
      final seenLinkKeys = <String>{};

      for (final variant in _decodeEpisodeVariants(epData)) {
        Map<String, dynamic> response;
        try {
          response = await _client.pipeRequest(
            'sources',
            query: variant.toQuery(),
          );
        } catch (_) {
          continue;
        }
        if (!response.containsKey('streams')) {
          continue;
        }

        final streams = response['streams'] as List<dynamic>;
        final subtitles = _mapExternalSubtitles(response['subtitles']);

        for (int i = 0; i < streams.length; i++) {
          final stream = streams[i];
          if (stream is! Map<String, dynamic>) {
            continue;
          }
          final type = stream['type'] as String?;
          final url = stream['url'] as String?;
          if (url == null) {
            continue;
          }

          final uri = Uri.tryParse(url);
          if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
            continue;
          }

          // DEBUG: Log the URL and host for investigation
          print('[MIRURO-DEBUG] Stream URL: $url');
          print('[MIRURO-DEBUG] Host: ${uri.host}');
          print('[MIRURO-DEBUG] Type: $type');

          final quality = stream['quality'] ?? stream['server'] ?? 'Auto';
          final dedupeKey =
              '${variant.provider}|${variant.category}|${uri.toString()}';
          if (!seenLinkKeys.add(dedupeKey)) {
            continue;
          }

          final isDirect = _isDirectStreamType(type);

          links.add(
            SourceServerLink(
              serverId: '${variant.provider}-$type-$quality-$i',
              serverName: _formatServerName(
                variant.provider,
                quality.toString(),
              ),
              initialUrl: uri,
              language: variant.category,
              linkType: SourceServerLinkType.stream,
              detectedHost: uri.host.toLowerCase(),
              externalSubtitles: subtitles,
              isDirectStream: isDirect,
            ),
          );
        }
      }

      return Success(links);
    } catch (e) {
      return Failure(SimpleError(code: 'SOURCES_ERROR', message: e.toString()));
    }
  }
}

bool _isDirectStreamType(String? type) => type == 'hls' || type == 'mp4';

String _formatServerName(String provider, String quality) {
  String friendlyProvider;
  switch (provider.toLowerCase()) {
    case 'kiwi':
      friendlyProvider = 'Kwik (AnimePahe)';
      break;
    case 'zoro':
      friendlyProvider = 'MegaCloud (HiAnime)';
      break;
    case 'arc':
      friendlyProvider = 'Kwik Alt (AnimePahe)';
      break;
    case 'bee':
      friendlyProvider = 'Bee';
      break;
    case 'pewe':
      friendlyProvider = 'Pewe';
      break;
    case 'bonk':
      friendlyProvider = 'Bonk';
      break;
    case 'moo':
      friendlyProvider = 'Moo';
      break;
    case 'ally':
      friendlyProvider = 'Ally';
      break;
    case 'hop':
      friendlyProvider = 'Hop';
      break;
    default:
      friendlyProvider =
          provider.substring(0, 1).toUpperCase() +
          provider.substring(1).toLowerCase();
  }

  String cleanQuality = quality.replaceAll(RegExp(r'[-_]+$'), '').trim();
  if (cleanQuality.toLowerCase() == 'kiswi-stream' ||
      cleanQuality.toLowerCase() == 'kiswi stream') {
    cleanQuality = 'Auto';
  }
  if (cleanQuality.isEmpty) {
    cleanQuality = 'Auto';
  }

  return '$friendlyProvider $cleanQuality'.trim();
}

List<ExternalSubtitleTrack> _mapExternalSubtitles(dynamic rawSubtitles) {
  if (rawSubtitles is! List) {
    return const <ExternalSubtitleTrack>[];
  }

  final tracks = <ExternalSubtitleTrack>[];
  for (int i = 0; i < rawSubtitles.length; i++) {
    final raw = rawSubtitles[i];
    if (raw is! Map<String, dynamic>) {
      continue;
    }

    final rawUrl =
        raw['url']?.toString() ??
        raw['file']?.toString() ??
        raw['src']?.toString();
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      continue;
    }

    final label =
        raw['label']?.toString() ??
        raw['lang']?.toString() ??
        raw['language']?.toString() ??
        'Subtitle ${i + 1}';
    final language =
        raw['lang']?.toString() ?? raw['language']?.toString() ?? label;
    final id =
        raw['id']?.toString() ??
        raw['kind']?.toString() ??
        '${language.toLowerCase().replaceAll(' ', '_')}-$i';
    final isDefault = raw['default'] == true || raw['isDefault'] == true;

    tracks.add(
      ExternalSubtitleTrack(
        id: id,
        label: label,
        language: language,
        uri: uri,
        isDefault: isDefault,
      ),
    );
  }

  return tracks;
}

List<String> _orderedProviderKeys(Map<String, dynamic> providers) {
  final ordered = <String>[];
  final seen = <String>{};

  for (final provider in _preferredProviders) {
    if (providers.containsKey(provider) && seen.add(provider)) {
      ordered.add(provider);
    }
  }

  for (final provider in providers.keys) {
    final normalized = provider.toString();
    if (seen.add(normalized)) {
      ordered.add(normalized);
    }
  }

  return ordered;
}

List<String> _orderedCategoryKeys(Map<String, dynamic> episodesData) {
  final ordered = <String>[];
  final seen = <String>{};

  for (final category in _preferredCategories) {
    if (episodesData.containsKey(category) && seen.add(category)) {
      ordered.add(category);
    }
  }

  for (final category in episodesData.keys) {
    final normalized = category.toString();
    if (seen.add(normalized)) {
      ordered.add(normalized);
    }
  }

  return ordered;
}

List<_MiruroEpisodeVariant> _decodeEpisodeVariants(
  Map<String, dynamic> epData,
) {
  final variants = <_MiruroEpisodeVariant>[];
  final rawVariants = epData['variants'];

  if (rawVariants is List) {
    for (final rawVariant in rawVariants) {
      if (rawVariant is! Map<String, dynamic>) {
        continue;
      }
      final variant = _MiruroEpisodeVariant.fromJson(
        rawVariant,
        fallbackAnilistId: epData['anilistId'],
      );
      if (variant != null) {
        variants.add(variant);
      }
    }
  }

  if (variants.isNotEmpty) {
    return variants;
  }

  final legacyVariant = _MiruroEpisodeVariant.fromJson(epData);
  return legacyVariant == null
      ? const <_MiruroEpisodeVariant>[]
      : <_MiruroEpisodeVariant>[legacyVariant];
}

final class _MiruroEpisodeAccumulator {
  _MiruroEpisodeAccumulator({required this.anilistId, required this.number});

  final String anilistId;
  final double number;
  final List<_MiruroEpisodeVariant> _variants = <_MiruroEpisodeVariant>[];
  final Set<String> _variantKeys = <String>{};

  String? _primaryEpisodeId;
  String? _primaryProvider;
  String? _primaryCategory;
  String? _title;
  Uri? _thumbnailUrl;

  bool get hasVariants => _variants.isNotEmpty;

  void addVariant({
    required String provider,
    required String category,
    required String episodeId,
    required Map<String, dynamic> rawEpisode,
  }) {
    final variantKey = '$provider|$category|$episodeId';
    if (!_variantKeys.add(variantKey)) {
      return;
    }

    _variants.add(
      _MiruroEpisodeVariant(
        episodeId: episodeId,
        provider: provider,
        category: category,
        anilistId: anilistId,
      ),
    );

    _primaryEpisodeId ??= episodeId;
    _primaryProvider ??= provider;
    _primaryCategory ??= category;

    final title = rawEpisode['title']?.toString().trim();
    if ((_title == null || _title!.isEmpty) &&
        title != null &&
        title.isNotEmpty) {
      _title = title;
    }

    _thumbnailUrl ??= rawEpisode['image'] != null
        ? Uri.tryParse(rawEpisode['image'].toString())
        : null;
  }

  SourceEpisode toSourceEpisode() {
    return SourceEpisode(
      sourceEpisodeId: jsonEncode(<String, dynamic>{
        'episodeId': _primaryEpisodeId,
        'provider': _primaryProvider,
        'category': _primaryCategory,
        'anilistId': anilistId,
        'variants': _variants.map((variant) => variant.toJson()).toList(),
      }),
      number: number,
      title:
          _title ??
          'Episode ${number.toStringAsFixed(number % 1 == 0 ? 0 : 1)}',
      episodeUrl: Uri.parse('https://www.miruro.tv/watch/$anilistId'),
      thumbnailUrl: _thumbnailUrl,
    );
  }
}

final class _MiruroEpisodeVariant {
  const _MiruroEpisodeVariant({
    required this.episodeId,
    required this.provider,
    required this.category,
    required this.anilistId,
  });

  final String episodeId;
  final String provider;
  final String category;
  final String anilistId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'episodeId': episodeId,
      'provider': provider,
      'category': category,
      'anilistId': anilistId,
    };
  }

  Map<String, dynamic> toQuery() {
    return <String, dynamic>{
      'episodeId': episodeId,
      'provider': provider,
      'category': category,
      'anilistId': int.tryParse(anilistId) ?? anilistId,
    };
  }

  static _MiruroEpisodeVariant? fromJson(
    Map<String, dynamic> json, {
    Object? fallbackAnilistId,
  }) {
    final episodeId = json['episodeId']?.toString().trim();
    final provider = json['provider']?.toString().trim();
    final category = json['category']?.toString().trim();
    final anilistId = (json['anilistId'] ?? fallbackAnilistId)
        ?.toString()
        .trim();

    if (episodeId == null ||
        episodeId.isEmpty ||
        provider == null ||
        provider.isEmpty ||
        category == null ||
        category.isEmpty ||
        anilistId == null ||
        anilistId.isEmpty) {
      return null;
    }

    return _MiruroEpisodeVariant(
      episodeId: episodeId,
      provider: provider,
      category: category,
      anilistId: anilistId,
    );
  }
}
