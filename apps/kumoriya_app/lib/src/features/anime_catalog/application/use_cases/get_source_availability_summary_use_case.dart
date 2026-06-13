import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_source_matcher.dart';
import '../models/source_availability.dart';
import '../services/resolver_registry.dart';
import '../services/source_selection_policy.dart';
import 'check_source_availability_use_case.dart';
import 'get_source_episode_server_links_use_case.dart';

const Map<String, Duration> _defaultSourceAvailabilityTimeoutOverrides =
    <String, Duration>{
      // Miruro availability requires AniList-backed search plus a secure pipe
      // round-trip (`env2.js` -> `pipe/episodes`), which is consistently slower
      // than the lightweight HTML/API probes used by the other sources.
      'kumoriya.source.miruro': Duration(seconds: 4),
    };

final class GetSourceAvailabilitySummaryUseCase {
  const GetSourceAvailabilitySummaryUseCase({
    required List<SourcePlugin> sourcePlugins,
    required AnilistSourceMatcher matcher,
    required SourceSelectionPolicy selectionPolicy,
    required ResolverRegistry registry,
    Duration sourceTimeout = const Duration(milliseconds: 900),
    Map<String, Duration> sourceTimeoutOverrides =
        _defaultSourceAvailabilityTimeoutOverrides,
    bool probeAudioKinds = false,
  }) : _sourcePlugins = sourcePlugins,
       _matcher = matcher,
       _selectionPolicy = selectionPolicy,
       _registry = registry,
       _sourceTimeout = sourceTimeout,
       _sourceTimeoutOverrides = sourceTimeoutOverrides,
       _probeAudioKinds = probeAudioKinds;

  final List<SourcePlugin> _sourcePlugins;
  final AnilistSourceMatcher _matcher;
  final SourceSelectionPolicy _selectionPolicy;
  final ResolverRegistry _registry;
  final Duration _sourceTimeout;
  final Map<String, Duration> _sourceTimeoutOverrides;
  final bool _probeAudioKinds;

  Future<SourceAvailabilitySummary> call(
    AnimeDetail anilistDetail, {
    bool enforceSourceTimeout = true,
  }) async {
    final sources = await Future.wait(
      _sourcePlugins.map(
        (plugin) => _checkSource(
          plugin,
          anilistDetail,
          enforceSourceTimeout: enforceSourceTimeout,
        ),
      ),
    );

    final enriched = _probeAudioKinds
        ? await Future.wait(sources.map(_enrichAudioKinds))
        : sources;

    return SourceAvailabilitySummary(
      sources: enriched,
      recommended: _selectionPolicy.selectRecommended(enriched),
    );
  }

  Future<SourceAvailability> _checkSource(
    SourcePlugin plugin,
    AnimeDetail anilistDetail, {
    required bool enforceSourceTimeout,
  }) async {
    try {
      final timeout = _sourceTimeoutFor(plugin);
      final availability = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: _matcher,
      ).call(anilistDetail);
      if (!enforceSourceTimeout) {
        return await availability;
      }
      return await availability.timeout(
        timeout,
        onTimeout: () => _timedOutAvailability(plugin, timeout),
      );
    } catch (error) {
      return SourceAvailability(
        manifest: plugin.manifest,
        status: SourceAvailabilityStatus.error,
        decision: const SourceMatchDecision(
          verdict: false,
          confidence: MatchConfidence.low,
          reason: 'Source availability failed.',
          acceptanceSignals: <String>[],
          rejectionSignals: <String>['source-availability-error'],
        ),
        errorMessage: error.toString(),
      );
    }
  }

  Duration _sourceTimeoutFor(SourcePlugin plugin) {
    return _sourceTimeoutOverrides[plugin.manifest.id] ?? _sourceTimeout;
  }

  SourceAvailability _timedOutAvailability(
    SourcePlugin plugin,
    Duration timeout,
  ) {
    return SourceAvailability(
      manifest: plugin.manifest,
      status: SourceAvailabilityStatus.error,
      decision: const SourceMatchDecision(
        verdict: false,
        confidence: MatchConfidence.low,
        reason: 'Source availability timed out.',
        acceptanceSignals: <String>[],
        rejectionSignals: <String>['source-availability-timeout'],
      ),
      errorMessage: 'Source availability exceeded $timeout.',
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
