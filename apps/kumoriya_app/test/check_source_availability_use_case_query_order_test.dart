import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/check_source_availability_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  test(
    'prefers latin-script AniList queries before native-script variants',
    () async {
      final plugin = _RecordingSourcePlugin();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: const AnilistSourceMatcher(),
      );

      await useCase(
        AnimeDetail(
          anime: const Anime(
            anilistId: 30,
            title: AnimeTitle(
              romaji: 'Shin Seiki Evangelion',
              english: 'Neon Genesis Evangelion',
              native: '新世紀エヴァンゲリオン',
            ),
            format: AnimeFormat.tv,
            releaseYear: 1995,
          ),
        ),
      );

      expect(plugin.queries, isNotEmpty);
      expect(plugin.queries.first, isNot('新世紀エヴァンゲリオン'));
      expect(
        plugin.queries.take(2),
        everyElement(
          isNot(
            contains(
              RegExp(
                r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff]',
                unicode: true,
              ),
            ),
          ),
        ),
      );
    },
  );
}

final class _RecordingSourcePlugin implements SourcePlugin {
  final List<String> queries = <String>[];

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'test.source',
    displayName: 'Test Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
    baseUrls: <String>['https://example.com'],
  );

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    return const Failure(
      SimpleError(code: 'not-supported', message: 'not used in test'),
    );
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return const Failure(
      SimpleError(code: 'not-supported', message: 'not used in test'),
    );
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return const Failure(
      SimpleError(code: 'not-supported', message: 'not used in test'),
    );
  }
}
