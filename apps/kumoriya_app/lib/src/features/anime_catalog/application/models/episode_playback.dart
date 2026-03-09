import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import 'resolved_server_link_result.dart';
import 'source_availability.dart';

enum EpisodePlaybackDecisionType { direct, selection, unavailable }

final class EpisodePlaybackOption {
  const EpisodePlaybackOption({
    required this.sourcePluginId,
    required this.sourceName,
    required this.sourceIconUrl,
    required this.sourceEpisode,
    required this.serverLink,
    required this.resolverId,
    required this.resolverName,
    this.audioKind,
    this.isPreferred = false,
    this.isRecommended = false,
  });

  final String sourcePluginId;
  final String sourceName;
  final String? sourceIconUrl;
  final SourceEpisode sourceEpisode;
  final SourceServerLink serverLink;
  final String resolverId;
  final String resolverName;
  final SourceAudioKind? audioKind;
  final bool isPreferred;
  final bool isRecommended;

  String get optionKey =>
      '$sourcePluginId|${serverLink.serverId}|${resolverId.toLowerCase()}';

  EpisodePlaybackOption copyWith({bool? isPreferred, bool? isRecommended}) {
    return EpisodePlaybackOption(
      sourcePluginId: sourcePluginId,
      sourceName: sourceName,
      sourceIconUrl: sourceIconUrl,
      sourceEpisode: sourceEpisode,
      serverLink: serverLink,
      resolverId: resolverId,
      resolverName: resolverName,
      audioKind: audioKind,
      isPreferred: isPreferred ?? this.isPreferred,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }
}

final class EpisodePlayerLaunch {
  const EpisodePlayerLaunch({required this.option, required this.resolved});

  final EpisodePlaybackOption option;
  final ResolvedServerLinkResult resolved;
}

final class EpisodePlaybackDecision {
  const EpisodePlaybackDecision._({
    required this.type,
    this.launch,
    this.options = const <EpisodePlaybackOption>[],
    this.autoSelectionFailed = false,
  });

  const EpisodePlaybackDecision.direct({
    required EpisodePlayerLaunch launch,
    bool autoSelectionFailed = false,
  }) : this._(
         type: EpisodePlaybackDecisionType.direct,
         launch: launch,
         autoSelectionFailed: autoSelectionFailed,
       );

  const EpisodePlaybackDecision.selection({
    required List<EpisodePlaybackOption> options,
    bool autoSelectionFailed = false,
  }) : this._(
         type: EpisodePlaybackDecisionType.selection,
         options: options,
         autoSelectionFailed: autoSelectionFailed,
       );

  const EpisodePlaybackDecision.unavailable({bool autoSelectionFailed = false})
    : this._(
        type: EpisodePlaybackDecisionType.unavailable,
        autoSelectionFailed: autoSelectionFailed,
      );

  final EpisodePlaybackDecisionType type;
  final EpisodePlayerLaunch? launch;
  final List<EpisodePlaybackOption> options;
  final bool autoSelectionFailed;
}
