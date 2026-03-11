import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_anime_nexus/kumoriya_resolver_anime_nexus.dart';
import 'package:kumoriya_resolver_anime_nexus/src/services/playback_proxy_server.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';

Future<void> main(List<String> args) async {
  final hasEpisodeArg =
      args.isNotEmpty && double.tryParse(args.last.trim()) != null;
  final queryArgs = hasEpisodeArg ? args.take(args.length - 1) : args;
  final query = queryArgs.isNotEmpty
      ? queryArgs.join(' ').trim()
      : 'Release that Witch';
  final targetEpisodeNumber = hasEpisodeArg
      ? double.tryParse(args.last.trim()) ?? 1
      : 1;

  try {
    final source = AnimeNexusSourcePlugin();
    final resolver = AnimeNexusResolverPlugin();
    final registry = ResolverRegistry(resolvers: <ResolverPlugin>[resolver]);
    final resolveUseCase = ResolveSourceServerLinkUseCase(registry: registry);

    final searchResult = await source.search(
      SourceSearchQuery(query: query, page: 1, limit: 10),
    );
    if (searchResult is Failure<List<SourceAnimeMatch>, KumoriyaError>) {
      _printJson(<String, Object?>{
        'phase': 'search',
        'query': query,
        'error': _errorMap(searchResult.error),
      });
      return;
    }

    final searchMatches =
        (searchResult as Success<List<SourceAnimeMatch>, KumoriyaError>).value;
    if (searchMatches.isEmpty) {
      _printJson(<String, Object?>{
        'phase': 'search',
        'query': query,
        'error': 'Anime Nexus returned zero search matches.',
      });
      return;
    }

    final selectedMatch =
        searchMatches.cast<SourceAnimeMatch?>().firstWhere(
          (match) => _normalize(match!.title) == _normalize(query),
          orElse: () => null,
        ) ??
        searchMatches.first;

    final detailResult = await source.getAnimeDetail(selectedMatch.sourceId);
    if (detailResult is Failure<SourceAnimeDetail, KumoriyaError>) {
      _printJson(<String, Object?>{
        'phase': 'detail',
        'query': query,
        'selectedMatch': _matchMap(selectedMatch),
        'error': _errorMap(detailResult.error),
      });
      return;
    }

    final detail =
        (detailResult as Success<SourceAnimeDetail, KumoriyaError>).value;

    final episodesResult = await source.getEpisodes(selectedMatch.sourceId);
    if (episodesResult is Failure<List<SourceEpisode>, KumoriyaError>) {
      _printJson(<String, Object?>{
        'phase': 'episodes',
        'query': query,
        'selectedMatch': _matchMap(selectedMatch),
        'detail': _detailMap(detail),
        'error': _errorMap(episodesResult.error),
      });
      return;
    }

    final episodes =
        (episodesResult as Success<List<SourceEpisode>, KumoriyaError>).value;
    final selectedEpisode =
        episodes.cast<SourceEpisode?>().firstWhere(
          (episode) => episode!.number == targetEpisodeNumber,
          orElse: () => null,
        ) ??
        episodes.first;

    final linksResult = await source.getEpisodeServerLinks(selectedEpisode);
    if (linksResult is Failure<List<SourceServerLink>, KumoriyaError>) {
      _printJson(<String, Object?>{
        'phase': 'serverLinks',
        'query': query,
        'selectedMatch': _matchMap(selectedMatch),
        'detail': _detailMap(detail),
        'episode': _episodeMap(selectedEpisode),
        'error': _errorMap(linksResult.error),
      });
      return;
    }

    final links =
        (linksResult as Success<List<SourceServerLink>, KumoriyaError>).value;
    final selectedLink = links.first;

    final resolveResult = await resolveUseCase.call(selectedLink);
    final resolveStatus = resolveResult.fold(
      onFailure: (error) => <String, Object?>{
        'status': 'failure',
        'error': _errorMap(error),
      },
      onSuccess: (ResolvedServerLinkResult value) => <String, Object?>{
        'status': 'success',
        'resolverId': value.resolverId,
        'resolverName': value.resolverName,
        'streamsCount': value.streams.length,
        'streams': value.streams
            .take(3)
            .map(
              (stream) => <String, Object?>{
                'url': stream.url.toString(),
                'qualityLabel': stream.qualityLabel,
                'mimeType': stream.mimeType,
                'isHls': stream.isHls,
              },
            )
            .toList(growable: false),
        'externalSubtitles': value.externalSubtitles
            .map(
              (track) => <String, Object?>{
                'id': track.id,
                'label': track.label,
                'language': track.language,
                'uri': track.uri?.toString(),
                'hasInlineData': track.data != null,
                'isDefault': track.isDefault,
              },
            )
            .toList(growable: false),
      },
    );

    _printJson(<String, Object?>{
      'query': query,
      'searchMatchesCount': searchMatches.length,
      'searchMatchesTop': searchMatches
          .take(5)
          .map(_matchMap)
          .toList(growable: false),
      'selectedMatch': _matchMap(selectedMatch),
      'detail': _detailMap(detail),
      'episodesCount': episodes.length,
      'selectedEpisode': _episodeMap(selectedEpisode),
      'serverLinksCount': links.length,
      'serverLinks': links
          .map(
            (link) => <String, Object?>{
              'serverId': link.serverId,
              'serverName': link.serverName,
              'language': link.language,
              'initialUrl': link.initialUrl.toString(),
              'detectedHost': link.detectedHost,
              'externalSubtitlesCount': link.externalSubtitles.length,
            },
          )
          .toList(growable: false),
      'resolve': resolveStatus,
    });
  } finally {
    await NexusPlaybackProxyServer.instance.shutdown();
  }
}

Map<String, Object?> _matchMap(SourceAnimeMatch match) => <String, Object?>{
  'sourceId': match.sourceId,
  'title': match.title,
  'releaseYear': match.releaseYear,
  'format': match.format.name,
  'thumbnailUrl': match.thumbnailUrl?.toString(),
};

Map<String, Object?> _detailMap(SourceAnimeDetail detail) => <String, Object?>{
  'sourceId': detail.sourceId,
  'title': detail.title,
  'releaseYear': detail.releaseYear,
  'format': detail.format.name,
  'thumbnailUrl': detail.thumbnailUrl?.toString(),
  'synopsisLength': detail.synopsis?.length,
};

Map<String, Object?> _episodeMap(SourceEpisode episode) => <String, Object?>{
  'sourceEpisodeId': episode.sourceEpisodeId,
  'number': episode.number,
  'title': episode.title,
  'episodeUrl': episode.episodeUrl.toString(),
  'thumbnailUrl': episode.thumbnailUrl?.toString(),
};

Map<String, Object?> _errorMap(KumoriyaError error) => <String, Object?>{
  'code': error.code,
  'kind': error.kind.name,
  'message': error.message,
};

String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

void _printJson(Map<String, Object?> payload) {
  const encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(encoder.convert(payload));
}
