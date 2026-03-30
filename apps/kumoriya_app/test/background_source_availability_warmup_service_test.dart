import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/background_source_availability_warmup_service.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_availability_cache_codec.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_selection_policy.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/get_source_availability_summary_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/load_source_availability_summary_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;
  late DriftSourceAvailabilityStore store;
  late _WarmupTestSourcePlugin plugin;
  late LoadSourceAvailabilitySummaryUseCase loadUseCase;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSourceAvailabilityStore(db);
    plugin = _WarmupTestSourcePlugin();
    final codec = SourceAvailabilityCacheCodec(
      sourcePlugins: <SourcePlugin>[plugin],
      selectionPolicy: const SourceSelectionPolicy(),
    );
    loadUseCase = LoadSourceAvailabilitySummaryUseCase(
      store: store,
      computeUseCase: GetSourceAvailabilitySummaryUseCase(
        sourcePlugins: <SourcePlugin>[plugin],
        matcher: const AnilistSourceMatcher(),
        selectionPolicy: const SourceSelectionPolicy(),
        registry: ResolverRegistry(resolvers: <ResolverPlugin>[]),
      ),
      sourcePlugins: <SourcePlugin>[plugin],
      cacheCodec: codec,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('warms multiple anime ids and skips failures', () async {
    final details = <int, AnimeDetail>{
      7001: _detail(7001, 'Oshi no Ko'),
      7002: _detail(7002, 'Sousou no Frieren'),
    };
    final service = BackgroundSourceAvailabilityWarmupService(
      loadAnimeDetail: (anilistId) async {
        final detail = details[anilistId];
        if (detail == null) {
          return Failure(
            SimpleError(
              code: 'test.missing_detail',
              message: 'Missing test detail for $anilistId',
              kind: KumoriyaErrorKind.notFound,
            ),
          );
        }
        return Success(detail);
      },
      loadSourceAvailability: loadUseCase,
    );

    await service.warmUp(<int>[7001, 4040, 7002, 7001]);

    expect(plugin.searchCalls, 2);
    expect(plugin.episodeCalls, 2);

    final firstCache = await store.getAvailability(7001);
    final secondCache = await store.getAvailability(7002);
    final missingCache = await store.getAvailability(4040);

    expect(
      firstCache.fold(
        onSuccess: (records) => records.isNotEmpty,
        onFailure: (_) => false,
      ),
      isTrue,
    );
    expect(
      secondCache.fold(
        onSuccess: (records) => records.isNotEmpty,
        onFailure: (_) => false,
      ),
      isTrue,
    );
    expect(
      missingCache.fold(
        onSuccess: (records) => records,
        onFailure: (_) => const <SourceAvailabilityCacheRecord>[],
      ),
      isEmpty,
    );
  });
}

AnimeDetail _detail(int anilistId, String title) {
  return AnimeDetail(
    anime: Anime(
      anilistId: anilistId,
      title: AnimeTitle(romaji: title),
      format: AnimeFormat.tv,
      releaseYear: 2024,
    ),
  );
}

final class _WarmupTestSourcePlugin implements SourcePlugin {
  int searchCalls = 0;
  int episodeCalls = 0;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'test.source.warmup',
    displayName: 'Warmup Test Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
    },
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    episodeCalls++;
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: '$sourceId-1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/$sourceId/1'),
      ),
    ]);
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    return const Success(<SourceServerLink>[]);
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    searchCalls++;
    final normalizedTitle = query.query.trim();
    if (normalizedTitle.isEmpty) {
      return const Success(<SourceAnimeMatch>[]);
    }

    return Success(<SourceAnimeMatch>[
      SourceAnimeMatch(
        sourceId: normalizedTitle.toLowerCase().replaceAll(' ', '-'),
        title: normalizedTitle,
        format: AnimeFormat.tv,
        releaseYear: 2024,
      ),
    ]);
  }
}
