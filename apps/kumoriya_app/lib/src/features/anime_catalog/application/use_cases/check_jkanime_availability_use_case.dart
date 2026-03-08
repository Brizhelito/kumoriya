import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_jkanime_matcher.dart';
import '../models/source_availability.dart';

final class CheckJkanimeAvailabilityUseCase {
  const CheckJkanimeAvailabilityUseCase({
    required SourcePlugin sourcePlugin,
    required AnilistJkanimeMatcher matcher,
  }) : _sourcePlugin = sourcePlugin,
       _matcher = matcher;

  final SourcePlugin _sourcePlugin;
  final AnilistJkanimeMatcher _matcher;

  Future<Result<SourceAvailability, KumoriyaError>> call(
    AnimeDetail anilistDetail,
  ) async {
    final searchResult = await _sourcePlugin.search(
      SourceSearchQuery(query: anilistDetail.anime.title.romaji, limit: 20),
    );

    return searchResult.fold(
      onFailure: Failure.new,
      onSuccess: (candidates) async {
        final decision = _matcher.decideMatch(
          anilistDetail: anilistDetail,
          candidates: candidates,
        );

        if (!decision.verdict || decision.candidate == null) {
          return Success(
            SourceAvailability(
              status: SourceAvailabilityStatus.unavailable,
              decision: decision,
            ),
          );
        }

        final episodesResult = await _sourcePlugin.getEpisodes(
          decision.candidate!.sourceId,
        );
        return episodesResult.fold(
          onFailure: Failure.new,
          onSuccess: (episodes) => Success(
            SourceAvailability(
              status: SourceAvailabilityStatus.available,
              decision: decision,
              episodes: episodes,
            ),
          ),
        );
      },
    );
  }
}
