import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../../../../app/l10n.dart';

import '../../application/models/server_quality_registry.dart';
import '../../application/models/source_availability.dart';
import '../../application/services/resolver_registry.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../providers/anime_catalog_providers.dart';
import '../support/plugin_icon_helpers.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';

// ─── Public entry-point ───────────────────────────────────────────────────────

/// Shows a bottom sheet that lets the user pick a source for bulk-download.
///
/// Sources are listed immediately; quality probing happens in the background
/// so the sheet appears without any blocking delay. Each row shows a quality
/// badge that updates as the probe for that source resolves.
///
/// [sampleEpisodes] maps each source's plugin-id to a representative episode
/// that will be used for probing.
///
/// [filterLinks] is an optional function applied to the resolved links before
/// scoring (e.g. to strip download-excluded hosts for a particular page).
///
/// Returns the chosen plugin-id, or `null` if dismissed.
Future<String?> showSourceQualityPickerSheet({
  required BuildContext context,
  required List<SourceAvailability> sources,
  required Map<String, SourceEpisode> sampleEpisodes,
  List<SourceServerLink> Function(List<SourceServerLink>)? filterLinks,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SourceQualityPickerSheet(
      sources: sources,
      sampleEpisodes: sampleEpisodes,
      filterLinks: filterLinks,
    ),
  );
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class SourceQualityPickerSheet extends ConsumerStatefulWidget {
  const SourceQualityPickerSheet({
    super.key,
    required this.sources,
    required this.sampleEpisodes,
    this.filterLinks,
  });

  final List<SourceAvailability> sources;

  /// Map from source plugin-id → sample episode for probing.
  final Map<String, SourceEpisode> sampleEpisodes;

  /// Optional post-filter applied to resolved links before tier scoring.
  final List<SourceServerLink> Function(List<SourceServerLink>)? filterLinks;

  @override
  ConsumerState<SourceQualityPickerSheet> createState() =>
      _SourceQualityPickerSheetState();
}

class _SourceQualityPickerSheetState
    extends ConsumerState<SourceQualityPickerSheet> {
  // null  → still probing
  // tier  → resolved (including ServerQualityTier.unavailable on failure)
  late final Map<String, ServerQualityTier?> _quality;

  @override
  void initState() {
    super.initState();
    _quality = {for (final s in widget.sources) s.manifest.id: null};
    _probeAll();
  }

  Future<void> _probeAll() async {
    final registry = ref.read(resolverRegistryProvider);
    // Fire all probes concurrently so they resolve as fast as possible.
    await Future.wait(widget.sources.map((s) => _probeSource(s, registry)));
  }

  Future<void> _probeSource(
    SourceAvailability source,
    ResolverRegistry registry,
  ) async {
    final sampleEpisode = widget.sampleEpisodes[source.manifest.id];
    if (sampleEpisode == null) {
      _setTier(source.manifest.id, ServerQualityTier.unavailable);
      return;
    }

    final sourcePlugin = ref.read(sourcePluginByIdProvider(source.manifest.id));

    final linksResult = await GetSourceEpisodeServerLinksUseCase(
      sourcePlugin: sourcePlugin,
      registry: registry,
      includeDownloadLinks: true,
    ).call(sampleEpisode);

    if (!mounted) return;

    linksResult.fold(
      onSuccess: (links) {
        final filtered = widget.filterLinks?.call(links) ?? links;
        if (filtered.isEmpty) {
          _setTier(source.manifest.id, ServerQualityTier.unavailable);
          return;
        }
        var bestTier = ServerQualityTier.unknown;
        for (final link in filtered) {
          final tier = ServerQualityRegistry.tierFor(
            detectedHost: link.detectedHost,
            serverName: link.serverName,
          );
          if (tier.weight > bestTier.weight) bestTier = tier;
        }
        _setTier(source.manifest.id, bestTier);
      },
      onFailure: (_) =>
          _setTier(source.manifest.id, ServerQualityTier.unavailable),
    );
  }

  void _setTier(String sourceId, ServerQualityTier tier) {
    if (!mounted) return;
    setState(() => _quality[sourceId] = tier);
  }

  @override
  Widget build(BuildContext context) {
    // Sort: resolved tiers by weight desc; still-loading (null) treated as
    // unknown weight so they don't dominate before results are available.
    final sorted = List<SourceAvailability>.of(widget.sources)
      ..sort((a, b) {
        final aWeight = _quality[a.manifest.id]?.weight ?? 0.4;
        final bWeight = _quality[b.manifest.id]?.weight ?? 0.4;
        return bWeight.compareTo(aWeight);
      });

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                context.l10n.downloadAllFromSource,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...sorted.map(
              (source) => _SourceTile(
                source: source,
                tier: _quality[source.manifest.id],
                onTap: () => Navigator.of(context).pop(source.manifest.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Private sub-widgets ──────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.tier,
    required this.onTap,
  });

  final SourceAvailability source;

  /// null means still probing.
  final ServerQualityTier? tier;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedTier = tier;
    return ListTile(
      leading: SourceBadge(
        sourceName: source.manifest.displayName,
        iconUrl: effectiveSourceIconUrl(source.manifest),
        compact: true,
        iconOnly: true,
      ),
      title: Text(
        source.manifest.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: <Widget>[
          if (resolvedTier == null)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            _QualityTierChip(tier: resolvedTier),
          ...source.availableAudioKinds.map(
            (kind) => _AudioKindChip(kind: kind),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _QualityTierChip extends StatelessWidget {
  const _QualityTierChip({required this.tier});

  final ServerQualityTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tier.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        tier.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tier.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AudioKindChip extends StatelessWidget {
  const _AudioKindChip({required this.kind});

  final SourceAudioKind kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      SourceAudioKind.sub => 'SUB',
      SourceAudioKind.dub => 'DUB',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.blueAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
