import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../anime_catalog/application/models/source_availability.dart';
import '../../anime_catalog/application/services/resolver_registry.dart';
import '../../anime_catalog/application/use_cases/get_source_episode_server_links_use_case.dart';
import '../../anime_catalog/presentation/providers/anime_catalog_providers.dart';

/// Probes the [sampleEpisode] of [sourcePluginId] to derive which
/// [SourceAudioKind]s (SUB / DUB / ...) the source actually exposes.
///
/// Used as a JIT detector before bulk-downloading so the user can be asked to
/// pick an audio variant when more than one is available — even if the cached
/// [SourceAvailability.availableAudioKinds] is empty.
///
/// Returns an empty set on any failure; callers should treat that as "no
/// preference" (download proceeds without a language filter).
Future<Set<SourceAudioKind>> probeAudioKindsForSource({
  required WidgetRef ref,
  required String sourcePluginId,
  required SourceEpisode sampleEpisode,
}) async {
  try {
    final sourcePlugin = ref.read(sourcePluginByIdProvider(sourcePluginId));
    final registry = ref.read(resolverRegistryProvider);
    return probeAudioKindsForPlugin(
      sourcePlugin: sourcePlugin,
      registry: registry,
      sampleEpisode: sampleEpisode,
    );
  } catch (_) {
    return const <SourceAudioKind>{};
  }
}

/// Pure variant of [probeAudioKindsForSource] that does not depend on Riverpod
/// providers. Exposed for unit tests and callers that already resolved their
/// [SourcePlugin] / [ResolverRegistry].
Future<Set<SourceAudioKind>> probeAudioKindsForPlugin({
  required SourcePlugin sourcePlugin,
  required ResolverRegistry registry,
  required SourceEpisode sampleEpisode,
}) async {
  try {
    final result = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: sourcePlugin,
      registry: registry,
      includeDownloadLinks: true,
    ).call(sampleEpisode);

    final links = result.fold(
      onSuccess: (l) => l,
      onFailure: (_) => const <SourceServerLink>[],
    );

    final kinds = <SourceAudioKind>{};
    for (final link in links) {
      final kind = sourceAudioKindFromCode(link.language);
      if (kind != null) kinds.add(kind);
    }
    return kinds;
  } catch (_) {
    return const <SourceAudioKind>{};
  }
}
