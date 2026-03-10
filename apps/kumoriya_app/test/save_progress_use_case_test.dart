import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import 'package:kumoriya_app/src/features/player/application/use_cases/save_progress_use_case.dart';

void main() {
  late AppDatabase db;
  late DriftAnimeProgressStore store;
  late SaveProgressUseCase useCase;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftAnimeProgressStore(db);
    useCase = SaveProgressUseCase(store: store);
  });

  tearDown(() async {
    await db.close();
  });

  test('does not save if position is below 5 seconds', () async {
    final result = await useCase(
      anilistId: 100,
      episodeNumber: 1.0,
      position: const Duration(seconds: 3),
      totalDuration: const Duration(minutes: 24),
    );

    expect(result, isA<Success>());

    final stored = await store.getProgress(100, 1.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value;
    expect(value, isNull);
  });

  test('saves progress when position >= 5 seconds', () async {
    final result = await useCase(
      anilistId: 100,
      episodeNumber: 1.0,
      position: const Duration(minutes: 10),
      totalDuration: const Duration(minutes: 24),
    );

    expect(result, isA<Success>());

    final stored = await store.getProgress(100, 1.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value;
    expect(value, isNotNull);
    expect(value!.position, const Duration(minutes: 10));
    expect(value.watchState, WatchState.watching);
  });

  test('marks as completed when position >= 90% of total duration', () async {
    await useCase(
      anilistId: 200,
      episodeNumber: 3.0,
      position: const Duration(minutes: 22),
      totalDuration: const Duration(minutes: 24),
    );

    final stored = await store.getProgress(200, 3.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value!;
    expect(value.watchState, WatchState.completed);
  });

  test('keeps watching state when position < 90% of total duration', () async {
    await useCase(
      anilistId: 300,
      episodeNumber: 5.0,
      position: const Duration(minutes: 12),
      totalDuration: const Duration(minutes: 24),
    );

    final stored = await store.getProgress(300, 5.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value!;
    expect(value.watchState, WatchState.watching);
  });

  test('defaults to watching when totalDuration is null', () async {
    await useCase(
      anilistId: 400,
      episodeNumber: 1.0,
      position: const Duration(minutes: 15),
    );

    final stored = await store.getProgress(400, 1.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value!;
    expect(value.watchState, WatchState.watching);
  });

  test('persists resolver and source metadata', () async {
    await useCase(
      anilistId: 500,
      episodeNumber: 2.0,
      position: const Duration(minutes: 8),
      totalDuration: const Duration(minutes: 24),
      lastSourcePluginId: 'jkanime',
      lastServerName: 'Streamwish',
      lastResolverPluginId: 'kumoriya.resolver.streamwish',
    );

    final stored = await store.getProgress(500, 2.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value!;
    expect(value.lastSourcePluginId, 'jkanime');
    expect(value.lastServerName, 'Streamwish');
    expect(value.lastResolverPluginId, 'kumoriya.resolver.streamwish');
  });

  test('clears persisted server metadata when next save omits it', () async {
    await useCase(
      anilistId: 501,
      episodeNumber: 2.0,
      position: const Duration(minutes: 8),
      totalDuration: const Duration(minutes: 24),
      lastSourcePluginId: 'jkanime',
      lastServerName: 'Streamwish',
      lastResolverPluginId: 'kumoriya.resolver.streamwish',
    );

    await useCase(
      anilistId: 501,
      episodeNumber: 2.0,
      position: const Duration(minutes: 9),
      totalDuration: const Duration(minutes: 24),
    );

    final stored = await store.getProgress(501, 2.0);
    final value = (stored as Success<EpisodeProgress?, KumoriyaError>).value!;
    expect(value.lastSourcePluginId, isNull);
    expect(value.lastServerName, isNull);
    expect(value.lastResolverPluginId, isNull);
  });
}
