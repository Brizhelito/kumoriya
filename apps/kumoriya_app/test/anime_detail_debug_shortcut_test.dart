import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/pages/anime_detail_page.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  testWidgets(
    'pressing D in debug shows clear persisted preferred player option',
    (tester) async {
      final store = _FakeAnimeProgressStore(
        preference: PlaybackPreference(
          anilistId: 101,
          preferredSourcePluginId: 'kumoriya.source.animeav1',
          preferredServerName: 'MP4Upload',
          preferredResolverPluginId: 'kumoriya.resolver.mp4upload',
          updatedAt: DateTime(2026, 3, 9),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animeProgressStoreProvider.overrideWithValue(store),
            animeDetailProvider.overrideWith(
              (ref, anilistId) async => Success(_detail(anilistId)),
            ),
            sourceAvailabilitySummaryProvider.overrideWith(
              (ref, anilistId) async => const Success(
                SourceAvailabilitySummary(sources: <SourceAvailability>[]),
              ),
            ),
            latestEpisodeProgressProvider.overrideWith(
              (ref, anilistId) async =>
                  const Success<EpisodeProgress?, KumoriyaError>(null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AnimeDetailPage(anilistId: 101),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();

      expect(find.text('Debug playback preference'), findsOneWidget);
      expect(find.text('Clear persisted preferred player'), findsOneWidget);

      await tester.tap(find.text('Clear persisted preferred player'));
      await tester.pumpAndSettle();

      expect(store.currentPreference, isNull);
      expect(find.text('Persisted preferred player cleared.'), findsOneWidget);
    },
  );
}

AnimeDetail _detail(int anilistId) {
  return AnimeDetail(
    anime: Anime(
      anilistId: anilistId,
      title: const AnimeTitle(romaji: 'Debug Anime'),
      format: AnimeFormat.tv,
      status: AnimeStatus.releasing,
      totalEpisodes: 12,
    ),
    synopsis: 'Debug synopsis',
    episodes: const <AnimeEpisode>[AnimeEpisode(number: 1, title: 'Episode 1')],
  );
}

final class _FakeAnimeProgressStore implements AnimeProgressStore {
  _FakeAnimeProgressStore({PlaybackPreference? preference})
    : currentPreference = preference;

  PlaybackPreference? currentPreference;

  @override
  Future<Result<void, KumoriyaError>> clearPlaybackPreference(
    int anilistId,
  ) async {
    currentPreference = null;
    return const Success(null);
  }

  @override
  Future<Result<List<EpisodeProgress>, KumoriyaError>> getAllProgress(
    int anilistId,
  ) async {
    return const Success(<EpisodeProgress>[]);
  }

  @override
  Future<Result<PlaybackPreference?, KumoriyaError>> getPlaybackPreference(
    int anilistId,
  ) async {
    return Success(currentPreference);
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getLatestProgress(
    int anilistId,
  ) async {
    return const Success(null);
  }

  @override
  Future<Result<EpisodeProgress?, KumoriyaError>> getProgress(
    int anilistId,
    double episodeNumber,
  ) async {
    return const Success(null);
  }

  @override
  Future<Result<List<AnimeWatchHistory>, KumoriyaError>> getRecentHistory({
    int limit = 20,
  }) async {
    return const Success(<AnimeWatchHistory>[]);
  }

  @override
  Future<Result<void, KumoriyaError>> upsert(EpisodeProgress progress) async {
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertPlaybackPreference(
    PlaybackPreference preference,
  ) async {
    currentPreference = preference;
    return const Success(null);
  }

  @override
  Future<Result<void, KumoriyaError>> upsertWatchHistory({
    required int anilistId,
    required double episodeNumber,
    required int positionSeconds,
    int? totalDurationSeconds,
    String? lastSourcePluginId,
  }) async {
    return const Success(null);
  }
}
