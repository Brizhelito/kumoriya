import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../application/models/episode_playback.dart';
import '../../application/models/source_availability.dart';
import '../providers/anime_catalog_providers.dart';
import '../widgets/source_badge.dart';
import '../../../player/presentation/pages/player_page.dart';

typedef PlaybackUnavailableFallback = FutureOr<void> Function();

Future<void> handlePlaybackDecision({
  required BuildContext context,
  required WidgetRef ref,
  required int anilistId,
  required String animeTitle,
  required EpisodePlaybackDecision decision,
  PlaybackUnavailableFallback? onUnavailable,
}) async {
  switch (decision.type) {
    case EpisodePlaybackDecisionType.direct:
      await _openPlayer(
        context,
        anilistId: anilistId,
        animeTitle: animeTitle,
        launch: decision.launch!,
      );
      return;
    case EpisodePlaybackDecisionType.selection:
      final option = await showServerPicker(
        context,
        options: decision.options,
        autoSelectionFailed: decision.autoSelectionFailed,
      );
      if (option != null && context.mounted) {
        await _resolveSelectedOption(
          context,
          ref,
          anilistId: anilistId,
          animeTitle: animeTitle,
          option: option,
          remaining: decision.options
              .where((item) => item.optionKey != option.optionKey)
              .toList(growable: false),
          onUnavailable: onUnavailable,
        );
      }
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

Future<EpisodePlaybackOption?> showServerPicker(
  BuildContext context, {
  required List<EpisodePlaybackOption> options,
  required bool autoSelectionFailed,
}) {
  return showModalBottomSheet<EpisodePlaybackOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                autoSelectionFailed
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        leading: const Icon(Icons.play_circle_outline_rounded),
                        title: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                option.serverLink.serverName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (option.isPreferred)
                              _ContextChip(
                                label: context.l10n.serverOptionLastUsed,
                              )
                            else if (option.isRecommended)
                              _ContextChip(
                                label: context.l10n.serverOptionRecommended,
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              SourceBadge(
                                name: option.sourceName,
                                iconUrl: option.sourceIconUrl,
                                audioKinds: option.audioKind == null
                                    ? const <SourceAudioKind>{}
                                    : <SourceAudioKind>{option.audioKind!},
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(option),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
  required EpisodePlaybackOption option,
  required List<EpisodePlaybackOption> remaining,
  PlaybackUnavailableFallback? onUnavailable,
}) async {
  showBlockingLoader(context, context.l10n.playbackOpeningSelectedServer);
  final result = await ref
      .read(resolveSourceServerLinkUseCaseProvider)
      .call(option.serverLink);
  if (!context.mounted) {
    return;
  }
  hideBlockingLoader(context);

  await result.fold(
    onFailure: (_) async {
      showPlaybackMessage(context, context.l10n.episodeSelectedServerFailed);
      if (remaining.isNotEmpty) {
        final next = await showServerPicker(
          context,
          options: remaining,
          autoSelectionFailed: true,
        );
        if (next != null && context.mounted) {
          await _resolveSelectedOption(
            context,
            ref,
            anilistId: anilistId,
            animeTitle: animeTitle,
            option: next,
            remaining: remaining
                .where((item) => item.optionKey != next.optionKey)
                .toList(growable: false),
            onUnavailable: onUnavailable,
          );
        }
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
        launch: EpisodePlayerLaunch(option: option, resolved: resolved),
      );
    },
  );
}

Future<void> _openPlayer(
  BuildContext context, {
  required int anilistId,
  required String animeTitle,
  required EpisodePlayerLaunch launch,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerPage(
        anilistId: anilistId,
        animeTitle: animeTitle,
        episodeNumber: launch.option.sourceEpisode.number.toInt().toString(),
        sourcePluginId: launch.option.sourcePluginId,
        serverName: launch.option.serverLink.serverName,
        preferredAudioPreference: switch (launch.option.audioKind) {
          SourceAudioKind.sub => PlaybackAudioPreference.sub,
          SourceAudioKind.dub => PlaybackAudioPreference.dub,
          null => null,
        },
        resolved: launch.resolved,
      ),
    ),
  );
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
