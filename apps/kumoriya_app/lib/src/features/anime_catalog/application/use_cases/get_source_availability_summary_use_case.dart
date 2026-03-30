import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_source_matcher.dart';
import '../models/source_availability.dart';
import '../services/resolver_registry.dart';
import '../services/source_selection_policy.dart';
import 'check_source_availability_use_case.dart';
import 'get_source_episode_server_links_use_case.dart';

final class GetSourceAvailabilitySummaryUseCase {
  const GetSourceAvailabilitySummaryUseCase({
    required List<SourcePlugin> sourcePlugins,
    required AnilistSourceMatcher matcher,
    required SourceSelectionPolicy selectionPolicy,
    required ResolverRegistry registry,
  }) : _sourcePlugins = sourcePlugins,
       _matcher = matcher,
       _selectionPolicy = selectionPolicy,
       _registry = registry;

  final List<SourcePlugin> _sourcePlugins;
  final AnilistSourceMatcher _matcher;
  final SourceSelectionPolicy _selectionPolicy;
  final ResolverRegistry _registry;

  Future<SourceAvailabilitySummary> call(AnimeDetail anilistDetail) async {
    final sources = await Future.wait(
      _sourcePlugins.map(
        (plugin) => CheckSourceAvailabilityUseCase(
          sourcePlugin: plugin,
          matcher: _matcher,
        ).call(anilistDetail),
      ),
    );

    final enriched = await Future.wait(sources.map(_enrichAudioKinds));

    return SourceAvailabilitySummary(
      sources: enriched,
      recommended: _selectionPolicy.selectRecommended(enriched),
    );
  }

  Future<SourceAvailability> _enrichAudioKinds(
    SourceAvailability availability,
  ) async {
    if (!availability.isAvailable || availability.episodes.isEmpty) {
      return availability;
    }

    final plugin = _sourcePlugins.firstWhere(
      (item) => item.manifest.id == availability.manifest.id,
      orElse: () => throw StateError(
        'Source plugin not found for ${availability.manifest.id}',
      ),
    );

    // Fetch server links for up to 3 episodes in parallel.
    final results = await Future.wait(
      availability.episodes
          .take(3)
          .map(
            (episode) => GetSourceEpisodeServerLinksUseCase(
              sourcePlugin: plugin,
              registry: _registry,
            ).call(episode),
          ),
    );

    final detectedKinds = <SourceAudioKind>{};
    for (final result in results) {
      result.fold(
        onFailure: (_) {},
        onSuccess: (links) {
          for (final link in links) {
            final audioKind = sourceAudioKindFromCode(link.language);
            if (audioKind != null) {
              detectedKinds.add(audioKind);
            }
          }
        },
      );
      if (detectedKinds.isNotEmpty) break;
    }

    if (detectedKinds.isEmpty) {
      return availability;
    }

    return availability.copyWith(availableAudioKinds: detectedKinds);
  }
}
