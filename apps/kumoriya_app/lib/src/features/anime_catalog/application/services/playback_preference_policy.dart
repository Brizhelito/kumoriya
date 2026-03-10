import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../models/episode_playback.dart';

final class PlaybackPreferenceReconciliation {
  const PlaybackPreferenceReconciliation({
    required this.durablePreference,
    required this.episodePreference,
    this.persistedPreferenceUpdate,
  });

  final PlaybackPreference? durablePreference;
  final PlaybackPreference? episodePreference;
  final PlaybackPreference? persistedPreferenceUpdate;
}

final class PlaybackPreferencePolicy {
  const PlaybackPreferencePolicy();

  static const Object _unchanged = Object();
  static const int _maxAutomaticAttemptsWithPreference = 4;

  PlaybackPreferenceReconciliation reconcile({
    required int anilistId,
    required PlaybackPreference? durablePreference,
    required EpisodeProgress? episodeProgress,
    required Set<String> sourceIdsWithEpisode,
    required List<EpisodePlaybackOption> options,
  }) {
    final episodePreference = _episodePreference(anilistId, episodeProgress);
    if (durablePreference == null) {
      return PlaybackPreferenceReconciliation(
        durablePreference: null,
        episodePreference: episodePreference,
      );
    }

    var next = durablePreference;

    final preferredSourceId = durablePreference.preferredSourcePluginId;
    if (preferredSourceId != null &&
        !sourceIdsWithEpisode.contains(preferredSourceId)) {
      next = _copyPreference(
        base: next,
        preferredSourcePluginId: null,
        preferredServerName: null,
        preferredResolverPluginId: null,
      );
    }

    final scopedOptions = next.preferredSourcePluginId == null
        ? options
        : options
              .where(
                (option) =>
                    option.sourcePluginId == next.preferredSourcePluginId,
              )
              .toList(growable: false);

    if (next.preferredServerName != null &&
        !scopedOptions.any(
          (option) => option.serverLink.serverName == next.preferredServerName,
        )) {
      next = _copyPreference(
        base: next,
        preferredServerName: null,
        preferredResolverPluginId: null,
      );
    }

    final resolverScopedOptions = next.preferredServerName == null
        ? scopedOptions
        : scopedOptions
              .where(
                (option) =>
                    option.serverLink.serverName == next.preferredServerName,
              )
              .toList(growable: false);

    if (next.preferredResolverPluginId != null &&
        !resolverScopedOptions.any(
          (option) => option.resolverId == next.preferredResolverPluginId,
        )) {
      next = _copyPreference(base: next, preferredResolverPluginId: null);
    }

    final persistedPreferenceUpdate =
        _equivalentSelection(durablePreference, next) ? null : next;

    return PlaybackPreferenceReconciliation(
      durablePreference: next,
      episodePreference: episodePreference,
      persistedPreferenceUpdate: persistedPreferenceUpdate,
    );
  }

  List<EpisodePlaybackOption> rankOptions({
    required List<EpisodePlaybackOption> options,
    required PlaybackPreference? durablePreference,
    required PlaybackPreference? episodePreference,
    required int Function(String pluginId) sourcePriorityIndex,
  }) {
    final ranked = [...options];
    ranked.sort(
      (left, right) =>
          _scoreOption(
            right,
            durablePreference: durablePreference,
            episodePreference: episodePreference,
            sourcePriorityIndex: sourcePriorityIndex,
          ).compareTo(
            _scoreOption(
              left,
              durablePreference: durablePreference,
              episodePreference: episodePreference,
              sourcePriorityIndex: sourcePriorityIndex,
            ),
          ),
    );

    if (ranked.isEmpty) {
      return ranked;
    }

    final recommendedKey = ranked.first.optionKey;
    return ranked
        .map(
          (option) => option.copyWith(
            isPreferred:
                _matchesExactPreference(option, episodePreference) ||
                _matchesExactPreference(option, durablePreference),
            isRecommended: option.optionKey == recommendedKey,
          ),
        )
        .toList(growable: false);
  }

  List<EpisodePlaybackOption> buildAutoQueue({
    required List<EpisodePlaybackOption> rankedOptions,
    required PlaybackPreference? durablePreference,
    required PlaybackPreference? episodePreference,
  }) {
    if (rankedOptions.isEmpty) {
      return const <EpisodePlaybackOption>[];
    }

    final queue = <EpisodePlaybackOption>[];
    final seen = <String>{};

    void add(EpisodePlaybackOption? option) {
      if (option == null || !seen.add(option.optionKey)) {
        return;
      }
      queue.add(option);
    }

    void addBestForSource(String? sourcePluginId) {
      if (sourcePluginId == null) {
        return;
      }
      for (final option in rankedOptions) {
        if (option.sourcePluginId == sourcePluginId &&
            !seen.contains(option.optionKey)) {
          add(option);
          return;
        }
      }
    }

    void addAllForSource(String? sourcePluginId) {
      if (sourcePluginId == null) {
        return;
      }
      for (final option in rankedOptions) {
        if (option.sourcePluginId == sourcePluginId) {
          add(option);
        }
      }
    }

    add(_findExactMatch(rankedOptions, episodePreference));
    add(_findExactMatch(rankedOptions, durablePreference));
    addBestForSource(episodePreference?.preferredSourcePluginId);
    addAllForSource(episodePreference?.preferredSourcePluginId);
    addBestForSource(durablePreference?.preferredSourcePluginId);
    addAllForSource(durablePreference?.preferredSourcePluginId);
    add(
      _onlyAudioMatch(
        rankedOptions,
        durablePreference?.preferredAudioPreference,
      ),
    );

    if (rankedOptions.length == 1) {
      add(rankedOptions.first);
      return queue;
    }

    if (episodePreference == null && durablePreference == null) {
      final topSourceId = rankedOptions.first.sourcePluginId;
      final topSourceOptions = rankedOptions
          .where((option) => option.sourcePluginId == topSourceId)
          .toList(growable: false);
      if (topSourceOptions.length == 1) {
        add(topSourceOptions.first);
      }
    } else {
      for (final option in rankedOptions) {
        add(option);
        if (queue.length >= _maxAutomaticAttemptsWithPreference) {
          break;
        }
      }
    }

    return queue;
  }

  int automaticAttemptLimit({
    required PlaybackPreference? durablePreference,
    required PlaybackPreference? episodePreference,
  }) {
    return episodePreference != null || durablePreference != null
        ? _maxAutomaticAttemptsWithPreference
        : 1;
  }

  PlaybackPreference? invalidateAfterAutoFailure({
    required PlaybackPreference? durablePreference,
    required EpisodePlaybackOption failedOption,
    required List<EpisodePlaybackOption> rankedOptions,
  }) {
    if (durablePreference == null) {
      return null;
    }

    var next = durablePreference;
    var changed = false;

    final sameSourceRemaining = rankedOptions.any(
      (option) =>
          option.optionKey != failedOption.optionKey &&
          option.sourcePluginId == failedOption.sourcePluginId,
    );
    final sameAudioRemaining =
        next.preferredAudioPreference != null &&
        rankedOptions.any(
          (option) =>
              option.optionKey != failedOption.optionKey &&
              option.audioKind?.name == next.preferredAudioPreference!.name,
        );

    if (_matchesExactPreference(failedOption, next)) {
      next = _copyPreference(
        base: next,
        preferredSourcePluginId: sameSourceRemaining
            ? failedOption.sourcePluginId
            : null,
        preferredServerName: null,
        preferredResolverPluginId: null,
      );
      changed = true;
    }

    if (next.preferredSourcePluginId == failedOption.sourcePluginId &&
        !sameSourceRemaining) {
      next = _copyPreference(
        base: next,
        preferredSourcePluginId: null,
        preferredServerName: null,
        preferredResolverPluginId: null,
      );
      changed = true;
    }

    if (next.preferredAudioPreference != null &&
        failedOption.audioKind?.name == next.preferredAudioPreference!.name &&
        !sameAudioRemaining) {
      next = _copyPreference(base: next, preferredAudioPreference: null);
      changed = true;
    }

    if (!changed || _equivalentSelection(durablePreference, next)) {
      return null;
    }

    return next;
  }

  List<EpisodePlaybackOption> remainingOptions({
    required List<EpisodePlaybackOption> options,
    required Set<String> attemptedOptionKeys,
  }) {
    return options
        .where((option) => !attemptedOptionKeys.contains(option.optionKey))
        .toList(growable: false);
  }

  List<EpisodePlaybackOption> rankRemainingOptions({
    required List<EpisodePlaybackOption> options,
    required Set<String> attemptedOptionKeys,
    required PlaybackPreference? durablePreference,
    required PlaybackPreference? episodePreference,
    required int Function(String pluginId) sourcePriorityIndex,
  }) {
    return rankOptions(
      options: remainingOptions(
        options: options,
        attemptedOptionKeys: attemptedOptionKeys,
      ),
      durablePreference: durablePreference,
      episodePreference: episodePreference,
      sourcePriorityIndex: sourcePriorityIndex,
    );
  }

  int _scoreOption(
    EpisodePlaybackOption option, {
    required PlaybackPreference? durablePreference,
    required PlaybackPreference? episodePreference,
    required int Function(String pluginId) sourcePriorityIndex,
  }) {
    var score = 1000 - sourcePriorityIndex(option.sourcePluginId) * 100;

    score += _preferenceScore(option, durablePreference, baseScore: 220);
    score += _preferenceScore(option, episodePreference, baseScore: 360);

    if (durablePreference?.preferredAudioPreference != null) {
      if (option.audioKind?.name ==
          durablePreference!.preferredAudioPreference!.name) {
        score += 120;
      } else if (option.audioKind != null) {
        score -= 40;
      }
    }

    return score;
  }

  int _preferenceScore(
    EpisodePlaybackOption option,
    PlaybackPreference? preference, {
    required int baseScore,
  }) {
    if (preference == null) {
      return 0;
    }

    var score = 0;
    if (option.sourcePluginId == preference.preferredSourcePluginId) {
      score += baseScore;
    }
    if (option.serverLink.serverName == preference.preferredServerName) {
      score += baseScore + 160;
    }
    if (option.resolverId == preference.preferredResolverPluginId) {
      score += baseScore ~/ 2;
    }
    if (option.audioKind != null &&
        preference.preferredAudioPreference != null &&
        option.audioKind!.name == preference.preferredAudioPreference!.name) {
      score += baseScore ~/ 3;
    }
    return score;
  }

  PlaybackPreference? _episodePreference(
    int anilistId,
    EpisodeProgress? progress,
  ) {
    if (progress == null) {
      return null;
    }
    final hasSignal =
        (progress.lastSourcePluginId?.trim().isNotEmpty ?? false) ||
        (progress.lastServerName?.trim().isNotEmpty ?? false) ||
        (progress.lastResolverPluginId?.trim().isNotEmpty ?? false);
    if (!hasSignal) {
      return null;
    }

    return PlaybackPreference(
      anilistId: anilistId,
      preferredSourcePluginId: progress.lastSourcePluginId,
      preferredServerName: progress.lastServerName,
      preferredResolverPluginId: progress.lastResolverPluginId,
      updatedAt: progress.updatedAt,
    );
  }

  EpisodePlaybackOption? _findExactMatch(
    List<EpisodePlaybackOption> options,
    PlaybackPreference? preference,
  ) {
    for (final option in options) {
      if (_matchesExactPreference(option, preference)) {
        return option;
      }
    }
    return null;
  }

  EpisodePlaybackOption? _onlyAudioMatch(
    List<EpisodePlaybackOption> options,
    PlaybackAudioPreference? audioPreference,
  ) {
    if (audioPreference == null) {
      return null;
    }
    final audioMatches = options
        .where((option) => option.audioKind?.name == audioPreference.name)
        .toList(growable: false);
    return audioMatches.length == 1 ? audioMatches.single : null;
  }

  bool _matchesExactPreference(
    EpisodePlaybackOption option,
    PlaybackPreference? preference,
  ) {
    if (preference == null) {
      return false;
    }

    if (preference.preferredSourcePluginId != null &&
        option.sourcePluginId != preference.preferredSourcePluginId) {
      return false;
    }
    if (preference.preferredServerName != null &&
        option.serverLink.serverName != preference.preferredServerName) {
      return false;
    }
    if (preference.preferredResolverPluginId != null &&
        option.resolverId != preference.preferredResolverPluginId) {
      return false;
    }
    if (preference.preferredAudioPreference != null &&
        option.audioKind?.name != preference.preferredAudioPreference!.name) {
      return false;
    }

    return preference.preferredServerName != null ||
        preference.preferredResolverPluginId != null ||
        preference.preferredAudioPreference != null;
  }

  bool _equivalentSelection(
    PlaybackPreference? left,
    PlaybackPreference? right,
  ) {
    if (left == null && right == null) {
      return true;
    }
    if (left == null || right == null) {
      return false;
    }
    return left.preferredSourcePluginId == right.preferredSourcePluginId &&
        left.preferredServerName == right.preferredServerName &&
        left.preferredResolverPluginId == right.preferredResolverPluginId &&
        left.preferredAudioPreference == right.preferredAudioPreference;
  }

  PlaybackPreference _copyPreference({
    required PlaybackPreference base,
    Object? preferredSourcePluginId = _unchanged,
    Object? preferredServerName = _unchanged,
    Object? preferredResolverPluginId = _unchanged,
    Object? preferredAudioPreference = _unchanged,
  }) {
    return PlaybackPreference(
      anilistId: base.anilistId,
      preferredSourcePluginId: identical(preferredSourcePluginId, _unchanged)
          ? base.preferredSourcePluginId
          : preferredSourcePluginId as String?,
      preferredServerName: identical(preferredServerName, _unchanged)
          ? base.preferredServerName
          : preferredServerName as String?,
      preferredResolverPluginId:
          identical(preferredResolverPluginId, _unchanged)
          ? base.preferredResolverPluginId
          : preferredResolverPluginId as String?,
      preferredAudioPreference: identical(preferredAudioPreference, _unchanged)
          ? base.preferredAudioPreference
          : preferredAudioPreference as PlaybackAudioPreference?,
      updatedAt: DateTime.now(),
    );
  }
}
