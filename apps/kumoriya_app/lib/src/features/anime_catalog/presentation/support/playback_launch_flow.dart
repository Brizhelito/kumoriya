import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/server_quality_registry.dart';
import '../../application/models/source_availability.dart';
import '../../application/services/resolver_registry.dart';
import '../../application/use_cases/get_source_episode_server_links_use_case.dart';
import '../providers/anime_catalog_providers.dart';
import '../providers/storage_providers.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import '../../../player/presentation/pages/player_page.dart';
import '../../../watch_party/presentation/party_route_mode.dart';

typedef PlaybackUnavailableFallback = FutureOr<void> Function();

final class ServerPickerSelection {
  const ServerPickerSelection({
    required this.option,
    required this.rememberSelection,
  });

  final EpisodePlaybackOption option;
  final bool rememberSelection;
}

Future<void> handlePlaybackDecision({
  required BuildContext context,
  required WidgetRef ref,
  required int anilistId,
  required String animeTitle,
  String? episodeTitle,
  required EpisodePlaybackDecision decision,
  PlaybackUnavailableFallback? onUnavailable,
  bool persistSelection = true,
  PartyRouteMode routeMode = PartyRouteMode.standard,
  int? totalEpisodes,
  double? nextAiringEpisodeNumber,
}) async {
  // In party mode the default is to NOT persist to avoid the host's
  // (or a one-off party) selection becoming the member's durable pref.
  // When the member checks the "remember" toggle in the server picker
  // it is passed as explicit `persistSelection: true`.
  final actualPersist = routeMode.isParty
      ? (persistSelection && false)
      : persistSelection;

  switch (decision.type) {
    case EpisodePlaybackDecisionType.direct:
      await _openPlayer(
        context,
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
        launch: decision.launch!,
        persistSelection: actualPersist,
        routeMode: routeMode,
        totalEpisodes: totalEpisodes,
        nextAiringEpisodeNumber: nextAiringEpisodeNumber,
      );
      return;
    case EpisodePlaybackDecisionType.selection:
      if (decision.options.length == 1) {
        await _resolveSelectedOption(
          context,
          ref,
          anilistId: anilistId,
          animeTitle: animeTitle,
          episodeTitle: episodeTitle,
          selection: ServerPickerSelection(
            option: decision.options.single,
            rememberSelection: true,
          ),
          remaining: const <EpisodePlaybackOption>[],
          onUnavailable: onUnavailable,
          routeMode: routeMode,
          totalEpisodes: totalEpisodes,
          nextAiringEpisodeNumber: nextAiringEpisodeNumber,
        );
        return;
      }
      final preferenceResult = await ref
          .read(animeProgressStoreProvider)
          .getPlaybackPreference(anilistId);
      final rememberedPreference = preferenceResult.fold(
        onFailure: (_) => null,
        onSuccess: (value) => value,
      );
      if (!context.mounted) {
        return;
      }
      final option = await showServerPicker(
        context,
        options: decision.options,
        autoSelectionFailed: decision.autoSelectionFailed,
        rememberedPreference: rememberedPreference,
      );
      if (option == null || !context.mounted) {
        return;
      }
      await _resolveSelectedOption(
        context,
        ref,
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
        selection: option,
        remaining: decision.options
            .where((item) => item.optionKey != option.option.optionKey)
            .toList(growable: false),
        onUnavailable: onUnavailable,
        routeMode: routeMode,
        totalEpisodes: totalEpisodes,
        nextAiringEpisodeNumber: nextAiringEpisodeNumber,
      );
      return;
    case EpisodePlaybackDecisionType.unavailable:
      if (onUnavailable != null) {
        await onUnavailable();
      } else if (context.mounted) {
        showPlaybackMessage(
          context,
          decision.autoSelectionFailed
              ? context.l10n.episodeAutoplayFailed
              : context.l10n.episodePlaybackUnavailable,
        );
      }
      return;
  }
}

/// Result of a party auto-resolve attempt. Used by member clients to
/// distinguish "happy path launched" from "fall back to the manual
/// picker" states.
enum PartyAutoResolveOutcome {
  /// The host's source + server was found locally, resolved, and the
  /// player was pushed.
  launched,

  /// The anime is not currently showing (e.g. detail page closed) —
  /// caller should drop the event silently.
  notActive,

  /// The host's source plugin is not installed or unavailable here.
  sourceUnavailable,

  /// The source exists but does not expose the requested episode.
  episodeUnavailable,

  /// The source + episode exists but the specific server name is not
  /// present on this client.
  serverUnavailable,

  /// The server link existed but the resolver failed to produce a
  /// playable stream.
  resolverFailed,
}

/// Try to auto-launch the player using the source + server the host
/// just announced via watch-party `source_selected`. Only runs for the
/// currently-mounted AnimeDetailPage (`anilistId` gate); all failure
/// paths return the specific [PartyAutoResolveOutcome] so the caller
/// can decide whether to show a hint or stay silent.
///
/// This function never throws — network/resolver failures are folded
/// into the outcome enum. On [PartyAutoResolveOutcome.launched] the
/// caller should NOT also push its own player.
Future<PartyAutoResolveOutcome> openPartySelectedSource({
  required BuildContext context,
  required WidgetRef ref,
  required int anilistId,
  required String animeTitle,
  required double episodeNumber,
  required String sourcePluginId,
  required String serverName,
  String? resolverPluginId,
  PartyRouteMode routeMode = PartyRouteMode.standard,
}) async {
  void log(String msg) {
    dev.log('party-auto-resolve: $msg', name: 'Party');
  }

  // 1. Read the cached availability summary. We purposely do not
  //    force-refresh — if the detail page has not loaded availability
  //    yet the auto-resolve is a no-op and the member simply goes
  //    through the manual flow.
  final summaryResult = await ref.read(
    sourceAvailabilitySummaryProvider(anilistId).future,
  );
  final summary = summaryResult.fold(
    onFailure: (_) => null,
    onSuccess: (value) => value,
  );
  if (summary == null) {
    log('no availability summary');
    return PartyAutoResolveOutcome.sourceUnavailable;
  }

  SourceAvailability? availability;
  for (final candidate in summary.sources) {
    if (candidate.manifest.id == sourcePluginId && candidate.isAvailable) {
      availability = candidate;
      break;
    }
  }
  if (availability == null) {
    log('source $sourcePluginId not available locally');
    return PartyAutoResolveOutcome.sourceUnavailable;
  }

  // 2. Find the matching episode. AniList numbering is authoritative;
  //    we compare by number (doubles may be fractional).
  SourceEpisode? episode;
  for (final candidate in availability.episodes) {
    if (candidate.number == episodeNumber) {
      episode = candidate;
      break;
    }
  }
  if (episode == null) {
    log('episode $episodeNumber not on source $sourcePluginId');
    return PartyAutoResolveOutcome.episodeUnavailable;
  }

  // 3. Fetch server links for this episode and pick the one whose
  //    server name matches the host's selection (case-insensitive so
  //    minor casing drift between source versions does not break us).
  final plugin = ref.read(sourcePluginByIdProvider(sourcePluginId));
  final registry = ref.read(resolverRegistryProvider);
  final linksResult = await GetSourceEpisodeServerLinksUseCase(
    sourcePlugin: plugin,
    registry: registry,
    // Include download-type links so the watch-party host's Mediafire
    // selection can match this client's candidate list.
    includeDownloadLinks: true,
  ).call(episode);
  final links = linksResult.fold(
    onFailure: (_) => const <SourceServerLink>[],
    onSuccess: (value) => value,
  );
  if (links.isEmpty) {
    log('no server links for episode $episodeNumber');
    return PartyAutoResolveOutcome.serverUnavailable;
  }

  final normalizedTarget = serverName.trim().toLowerCase();
  SourceServerLink? matchingLink;
  for (final link in links) {
    if (link.serverName.trim().toLowerCase() == normalizedTarget) {
      matchingLink = link;
      break;
    }
  }
  if (matchingLink == null) {
    log('server "$serverName" not found for episode $episodeNumber');
    return PartyAutoResolveOutcome.serverUnavailable;
  }

  // 4. Resolve via the registry. If the host hinted a specific resolver
  //    we prefer it, otherwise we fall back to the registry's default
  //    selection for the link.
  final selection = registry.selectFor(matchingLink.initialUrl);
  if (selection is! ResolverSelected) {
    log('no resolver registered for ${matchingLink.initialUrl}');
    return PartyAutoResolveOutcome.resolverFailed;
  }

  final option = EpisodePlaybackOption(
    sourcePluginId: availability.manifest.id,
    sourceName: availability.manifest.displayName,
    sourceIconUrl: availability.manifest.iconUrl,
    sourceEpisode: episode,
    serverLink: matchingLink,
    resolverId: selection.resolver.manifest.id,
    resolverName: selection.resolver.manifest.displayName,
    audioKind: sourceAudioKindFromCode(matchingLink.language),
  );

  final resolveResult = await ref
      .read(resolveSourceServerLinkUseCaseProvider)
      .call(matchingLink);
  if (!context.mounted) {
    return PartyAutoResolveOutcome.launched;
  }
  final resolved = resolveResult.fold(
    onFailure: (error) {
      log(
        'resolver failed code=${error.code} '
        'message=${error.message} url=${matchingLink?.initialUrl}',
      );
      return null;
    },
    onSuccess: (value) => value,
  );
  if (resolved == null) {
    return PartyAutoResolveOutcome.resolverFailed;
  }

  // 5. Hand off to the normal handler with a synthetic "direct"
  //    decision so the same PlayerPage lifecycle is exercised. We
  //    deliberately do NOT persist the selection: the host's choice is
  //    ephemeral and we do not want a member's durable preference to
  //    drift because of one party session.
  await handlePlaybackDecision(
    context: context,
    ref: ref,
    anilistId: anilistId,
    animeTitle: animeTitle,
    episodeTitle: episode.title.isEmpty ? null : episode.title,
    persistSelection: false,
    routeMode: routeMode,
    decision: EpisodePlaybackDecision.direct(
      launch: EpisodePlayerLaunch(option: option, resolved: resolved),
      autoSelectionFailed: false,
    ),
  );
  return PartyAutoResolveOutcome.launched;
}

Future<ServerPickerSelection?> showServerPicker(
  BuildContext context, {
  required List<EpisodePlaybackOption> options,
  required bool autoSelectionFailed,
  PlaybackPreference? rememberedPreference,
}) {
  return showModalBottomSheet<ServerPickerSelection>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return _ServerPickerSheet(
        options: options,
        autoSelectionFailed: autoSelectionFailed,
        rememberedPreference: rememberedPreference,
      );
    },
  );
}

void showBlockingLoader(BuildContext context, String label) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) {
      return PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void hideBlockingLoader(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}

void showPlaybackMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _resolveSelectedOption(
  BuildContext context,
  WidgetRef ref, {
  required int anilistId,
  required String animeTitle,
  String? episodeTitle,
  required ServerPickerSelection selection,
  required List<EpisodePlaybackOption> remaining,
  PlaybackUnavailableFallback? onUnavailable,
  PartyRouteMode routeMode = PartyRouteMode.standard,
  int? totalEpisodes,
  double? nextAiringEpisodeNumber,
}) async {
  showBlockingLoader(context, context.l10n.playbackOpeningSelectedServer);
  final result = await ref
      .read(resolveSourceServerLinkUseCaseProvider)
      .call(
        selection.option.serverLink,
        preferredResolverId: selection.option.resolverId,
      );
  if (!context.mounted) {
    return;
  }
  hideBlockingLoader(context);

  await result.fold(
    onFailure: (error) async {
      _log(
        'manual-open failure source=${selection.option.sourcePluginId} server=${selection.option.serverLink.serverName} resolver=${selection.option.resolverId} code=${error.code} message=${error.message}',
      );
      showPlaybackMessage(context, context.l10n.episodeSelectedServerFailed);
      if (remaining.isNotEmpty) {
        final next = await showServerPicker(
          context,
          options: remaining,
          autoSelectionFailed: true,
        );
        if (next == null || !context.mounted) {
          return;
        }
        await _resolveSelectedOption(
          context,
          ref,
          anilistId: anilistId,
          animeTitle: animeTitle,
          episodeTitle: episodeTitle,
          selection: next,
          remaining: remaining
              .where((item) => item.optionKey != next.option.optionKey)
              .toList(growable: false),
          onUnavailable: onUnavailable,
          routeMode: routeMode,
          totalEpisodes: totalEpisodes,
          nextAiringEpisodeNumber: nextAiringEpisodeNumber,
        );
        return;
      }
      if (onUnavailable != null) {
        await onUnavailable();
      }
    },
    onSuccess: (resolved) async {
      await _openPlayer(
        context,
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
        launch: EpisodePlayerLaunch(
          option: selection.option,
          resolved: resolved,
        ),
        persistSelection: selection.rememberSelection,
        routeMode: routeMode,
        totalEpisodes: totalEpisodes,
        nextAiringEpisodeNumber: nextAiringEpisodeNumber,
      );
    },
  );
}

void _log(String message) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('[playback.launch ${DateTime.now().toIso8601String()}] $message');
}

Future<bool> _openPlayer(
  BuildContext context, {
  required int anilistId,
  required String animeTitle,
  String? episodeTitle,
  required EpisodePlayerLaunch launch,
  bool persistSelection = true,
  PartyRouteMode routeMode = PartyRouteMode.standard,
  int? totalEpisodes,
  double? nextAiringEpisodeNumber,
}) async {
  final resolvedEpisodeTitle =
      episodeTitle ?? launch.option.sourceEpisode.title.trim();
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => PlayerPage(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: launch.option.sourceEpisode.number.toInt().toString(),
        episodeTitle: resolvedEpisodeTitle.isEmpty
            ? null
            : resolvedEpisodeTitle,
        sourcePluginId: launch.option.sourcePluginId,
        serverName: launch.option.serverLink.serverName,
        persistSelection: persistSelection,
        routeMode: routeMode,
        preferredAudioPreference: switch (launch.option.audioKind) {
          SourceAudioKind.sub => PlaybackAudioPreference.sub,
          SourceAudioKind.dub => PlaybackAudioPreference.dub,
          null => null,
        },
        resolved: launch.resolved,
        totalEpisodes: totalEpisodes,
        nextAiringEpisodeNumber: nextAiringEpisodeNumber,
      ),
    ),
  );
  return result == true;
}

class _ServerPickerSheet extends StatefulWidget {
  const _ServerPickerSheet({
    required this.options,
    required this.autoSelectionFailed,
    required this.rememberedPreference,
  });

  final List<EpisodePlaybackOption> options;
  final bool autoSelectionFailed;
  final PlaybackPreference? rememberedPreference;

  @override
  State<_ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends State<_ServerPickerSheet> {
  static const String _allSources = '__all_sources__';

  late bool _rememberSelection;
  String _selectedSourceId = _allSources;

  @override
  void initState() {
    super.initState();
    _rememberSelection = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupedOptions(widget.options);
    final sourceEntries = grouped.entries.toList(growable: false);
    final filteredEntries = _selectedSourceId == _allSources
        ? sourceEntries
        : sourceEntries
              .where((entry) => entry.key == _selectedSourceId)
              .toList(growable: false);
    final rememberedSummary = _rememberedSummary(context, widget.options);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.autoSelectionFailed
                    ? context.l10n.episodeAutoplayFailed
                    : context.l10n.serverPickerTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.serverPickerSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (rememberedSummary != null) ...<Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    context.l10n.serverPickerCurrentRemembered(
                      rememberedSummary.$1,
                      rememberedSummary.$2,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SwitchListTile.adaptive(
                value: _rememberSelection,
                onChanged: (value) {
                  setState(() => _rememberSelection = value);
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  context.l10n.serverPickerRememberSelectionTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  context.l10n.serverPickerRememberSelectionSubtitle,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(context.l10n.serverPickerAllSources),
                        selected: _selectedSourceId == _allSources,
                        onSelected: (_) {
                          setState(() => _selectedSourceId = _allSources);
                        },
                      ),
                    ),
                    ...sourceEntries.map((entry) {
                      final sourceOptions = entry.value;
                      final representative = sourceOptions.first;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _selectedSourceId == entry.key,
                          onSelected: (_) {
                            setState(() => _selectedSourceId = entry.key);
                          },
                          label: Text(
                            context.l10n.serverPickerSourceFilter(
                              representative.sourceName,
                              sourceOptions.length.toString(),
                            ),
                          ),
                          avatar: _SourceAvatar(
                            sourceName: representative.sourceName,
                            iconUrl: representative.sourceIconUrl,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    final sourceOptions = entry.value;
                    final representative = sourceOptions.first;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              SourceBadge(
                                sourceName: representative.sourceName,
                                iconUrl: representative.sourceIconUrl,
                                audioKinds: sourceOptions
                                    .map((item) => item.audioKind)
                                    .whereType<SourceAudioKind>()
                                    .toSet(),
                                compact: true,
                                isHighlighted: sourceOptions.any(
                                  (item) => item.isRecommended,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.serverPickerSourceOptionCount(
                                  sourceOptions.length.toString(),
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._buildOptionTiles(context, sourceOptions),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptionTiles(
    BuildContext context,
    List<EpisodePlaybackOption> options,
  ) {
    final widgets = <Widget>[];
    for (var index = 0; index < options.length; index++) {
      final option = options[index];
      if (index > 0) {
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(
        _ServerOptionTile(
          option: option,
          onTap: () {
            Navigator.of(context).pop(
              ServerPickerSelection(
                option: option,
                rememberSelection: _rememberSelection,
              ),
            );
          },
        ),
      );
    }
    return widgets;
  }

  Map<String, List<EpisodePlaybackOption>> _groupedOptions(
    List<EpisodePlaybackOption> options,
  ) {
    final grouped = <String, List<EpisodePlaybackOption>>{};
    for (final option in options) {
      final bucket = grouped.putIfAbsent(
        option.sourcePluginId,
        () => <EpisodePlaybackOption>[],
      );
      bucket.add(option);
    }
    return grouped;
  }

  (String, String)? _rememberedSummary(
    BuildContext context,
    List<EpisodePlaybackOption> options,
  ) {
    final preference = widget.rememberedPreference;
    if (preference == null) {
      return null;
    }

    final sourceName = options
        .where(
          (option) =>
              option.sourcePluginId == preference.preferredSourcePluginId,
        )
        .map((option) => option.sourceName)
        .cast<String?>()
        .firstWhere(
          (value) => value != null && value.trim().isNotEmpty,
          orElse: () => null,
        );

    final fallbackSource =
        preference.preferredSourcePluginId ??
        context.l10n.serverPickerUnknownSource;
    final fallbackServer =
        preference.preferredServerName ??
        context.l10n.serverPickerUnknownServer;
    return (sourceName ?? fallbackSource, fallbackServer);
  }
}

class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.sourceName, required this.iconUrl});

  final String sourceName;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    if (iconUrl != null && iconUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(iconUrl!),
        backgroundColor: Colors.transparent,
      );
    }

    return CircleAvatar(
      radius: 12,
      child: Text(sourceName.characters.first.toUpperCase()),
    );
  }
}

class _ServerOptionTile extends StatelessWidget {
  const _ServerOptionTile({required this.option, required this.onTap});

  final EpisodePlaybackOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.play_circle_outline_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            option.serverLink.serverName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (option.isPreferred)
                          _ContextChip(label: context.l10n.serverOptionLastUsed)
                        else if (option.isRecommended)
                          _ContextChip(
                            label: context.l10n.serverOptionRecommended,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _QualityTierBadge(
                          tier: ServerQualityRegistry.tierFor(
                            detectedHost: option.serverLink.detectedHost,
                            serverName: option.serverLink.serverName,
                          ),
                        ),
                        if (option.audioKind != null)
                          _MetaPill(
                            label: option.audioKind!.name.toUpperCase(),
                            icon: Icons.graphic_eq_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QualityTierBadge extends StatelessWidget {
  const _QualityTierBadge({required this.tier});

  final ServerQualityTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tier.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_iconForTier(tier), size: 13, color: tier.color),
          const SizedBox(width: 4),
          Text(
            tier.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tier.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForTier(ServerQualityTier tier) => switch (tier) {
    ServerQualityTier.premium => Icons.verified_rounded,
    ServerQualityTier.good => Icons.thumb_up_alt_outlined,
    ServerQualityTier.average => Icons.dns_outlined,
    ServerQualityTier.low => Icons.warning_amber_rounded,
    ServerQualityTier.unknown => Icons.help_outline_rounded,
    ServerQualityTier.unavailable => Icons.block_rounded,
  };
}
