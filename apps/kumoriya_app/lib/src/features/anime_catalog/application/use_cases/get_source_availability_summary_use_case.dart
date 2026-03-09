import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_source_matcher.dart';
import '../models/source_availability.dart';
import '../services/source_selection_policy.dart';
import 'check_source_availability_use_case.dart';

final class GetSourceAvailabilitySummaryUseCase {
  const GetSourceAvailabilitySummaryUseCase({
    required List<SourcePlugin> sourcePlugins,
    required AnilistSourceMatcher matcher,
    required SourceSelectionPolicy selectionPolicy,
  }) : _sourcePlugins = sourcePlugins,
       _matcher = matcher,
       _selectionPolicy = selectionPolicy;

  final List<SourcePlugin> _sourcePlugins;
  final AnilistSourceMatcher _matcher;
  final SourceSelectionPolicy _selectionPolicy;

  Future<SourceAvailabilitySummary> call(AnimeDetail anilistDetail) async {
    final sources = await Future.wait(
      _sourcePlugins.map(
        (plugin) => CheckSourceAvailabilityUseCase(
          sourcePlugin: plugin,
          matcher: _matcher,
        ).call(anilistDetail),
      ),
    );

    return SourceAvailabilitySummary(
      sources: sources,
      recommended: _selectionPolicy.selectRecommended(sources),
    );
  }
}
