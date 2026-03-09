import 'dart:convert';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_filemoon/kumoriya_resolver_filemoon.dart';
import 'package:kumoriya_resolver_jkplayer/kumoriya_resolver_jkplayer.dart';
import 'package:kumoriya_resolver_mixdrop/kumoriya_resolver_mixdrop.dart';
import 'package:kumoriya_resolver_mp4upload/kumoriya_resolver_mp4upload.dart';
import 'package:kumoriya_resolver_streamwish/kumoriya_resolver_streamwish.dart';
import 'package:kumoriya_resolver_voe/kumoriya_resolver_voe.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/resolved_server_link_result.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';

Future<void> main(List<String> args) async {
  final sourceId = args.isNotEmpty ? args.first : 'naruto';
  final maxEpisodes = args.length > 1 ? int.tryParse(args[1]) ?? 3 : 3;

  final source = JkAnimeSourcePlugin();
  final resolvers = <ResolverPlugin>[
    JkPlayerJkResolverPlugin(),
    JkPlayerResolverPlugin(),
    VoeResolverPlugin(),
    FilemoonResolverPlugin(),
    StreamwishResolverPlugin(),
    MixdropResolverPlugin(),
    Mp4uploadResolverPlugin(),
  ];

  final registry = ResolverRegistry(resolvers: resolvers);
  final useCase = ResolveSourceServerLinkUseCase(registry: registry);

  final inventory = resolvers
      .map(
        (resolver) => <String, Object?>{
          'id': resolver.manifest.id,
          'displayName': resolver.manifest.displayName,
          'priority': resolver.priority,
          'supportedHosts': resolver.manifest.supportedHosts,
          'baseUrls': resolver.manifest.baseUrls,
        },
      )
      .toList(growable: false);

  final episodesResult = await source.getEpisodes(sourceId);
  if (episodesResult is Failure<List<SourceEpisode>, KumoriyaError>) {
    final error = episodesResult.error;
    print(
      jsonEncode(<String, Object?>{
        'phase': 'getEpisodes',
        'sourceId': sourceId,
        'error': <String, Object?>{
          'code': error.code,
          'kind': error.kind.name,
          'message': error.message,
        },
      }),
    );
    return;
  }

  final episodes =
      (episodesResult as Success<List<SourceEpisode>, KumoriyaError>).value;
  final selectedEpisodes = episodes.take(maxEpisodes).toList(growable: false);

  final episodeReports = <Map<String, Object?>>[];

  for (final episode in selectedEpisodes) {
    final linksResult = await source.getEpisodeServerLinks(episode);
    if (linksResult is Failure<List<SourceServerLink>, KumoriyaError>) {
      final error = linksResult.error;
      episodeReports.add(<String, Object?>{
        'episode': <String, Object?>{
          'id': episode.sourceEpisodeId,
          'number': episode.number,
          'title': episode.title,
          'url': episode.episodeUrl.toString(),
        },
        'error': <String, Object?>{
          'code': error.code,
          'kind': error.kind.name,
          'message': error.message,
        },
      });
      continue;
    }

    final links =
        (linksResult as Success<List<SourceServerLink>, KumoriyaError>).value;

    final linkReports = <Map<String, Object?>>[];
    for (final link in links) {
      final url = link.initialUrl;
      final matchingResolvers = resolvers
          .where((resolver) => resolver.supports(url))
          .toList(growable: false);

      final supports = matchingResolvers
          .map((resolver) => resolver.manifest.id)
          .toList(growable: false);

      final selection = registry.selectFor(url);
      final selectionStatus = switch (selection) {
        ResolverSelected selected => <String, Object?>{
          'type': 'selected',
          'resolverId': selected.resolver.manifest.id,
        },
        ResolverAmbiguous ambiguous => <String, Object?>{
          'type': 'ambiguous',
          'resolverIds': ambiguous.resolvers
              .map((resolver) => resolver.manifest.id)
              .toList(growable: false),
        },
        ResolverNotFound _ => <String, Object?>{'type': 'not_found'},
      };

      final resolveResult = await useCase.call(link);
      final resolveStatus = resolveResult.fold(
        onFailure: (error) => <String, Object?>{
          'status': 'failure',
          'code': error.code,
          'kind': error.kind.name,
          'message': error.message,
        },
        onSuccess: (ResolvedServerLinkResult value) => <String, Object?>{
          'status': 'success',
          'resolverId': value.resolverId,
          'resolverName': value.resolverName,
          'streamsCount': value.streams.length,
          'streamUrls': value.streams
              .take(2)
              .map((stream) => stream.url.toString())
              .toList(growable: false),
        },
      );

      linkReports.add(<String, Object?>{
        'serverName': link.serverName,
        'detectedHost': link.detectedHost,
        'linkType': link.linkType.name,
        'initialUrl': url.toString(),
        'supports': supports,
        'selection': selectionStatus,
        'resolve': resolveStatus,
      });
    }

    episodeReports.add(<String, Object?>{
      'episode': <String, Object?>{
        'id': episode.sourceEpisodeId,
        'number': episode.number,
        'title': episode.title,
        'url': episode.episodeUrl.toString(),
      },
      'linksCount': links.length,
      'links': linkReports,
    });
  }

  final report = <String, Object?>{
    'sourceId': sourceId,
    'episodesRequested': maxEpisodes,
    'episodesAvailable': episodes.length,
    'inventory': inventory,
    'episodes': episodeReports,
  };

  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(report));
}
