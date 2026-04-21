import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_availability_cache_codec.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/source_selection_policy.dart';
import 'package:kumoriya_app/src/features/downloads/application/auto_download_new_episodes_service.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late _FakeLibraryStore libraryStore;
  late _FakeDownloadStore downloadStore;
  late _FakeSourceAvailabilityStore sourceAvailabilityStore;
  late _AutoDownloadTestSourcePlugin plugin;
  late SourceAvailabilityCacheCodec cacheCodec;

  setUp(() {
    libraryStore = _FakeLibraryStore();
    downloadStore = _FakeDownloadStore();
    sourceAvailabilityStore = _FakeSourceAvailabilityStore();
    plugin = _AutoDownloadTestSourcePlugin();
    cacheCodec = SourceAvailabilityCacheCodec(
      sourcePlugins: <SourcePlugin>[plugin],
      selectionPolicy: const SourceSelectionPolicy(),
    );
  });

  test('enqueues newly aired episodes when auto-download is enabled', () async {
    libraryStore.autoDownloadIds.add(7001);
    sourceAvailabilityStore.values[7001] = cacheCodec.encode(
      anilistId: 7001,
      updatedAt: DateTime.now(),
      summary: _summary(plugin.manifest.id, const <int>[1, 2, 3]),
    );

    final enqueuedEpisodes = <double>[];
    final service = AutoDownloadNewEpisodesService(
      libraryStore: libraryStore,
      downloadStore: downloadStore,
      sourceAvailabilityStore: sourceAvailabilityStore,
      sourceAvailabilityCacheCodec: cacheCodec,
      sourcePlugins: <SourcePlugin>[plugin],
      loadServerLinks:
          ({
            required SourcePlugin sourcePlugin,
            required SourceEpisode sourceEpisode,
          }) async {
            return Success(<SourceServerLink>[
              SourceServerLink(
                serverId: 'server-${sourceEpisode.number.toInt()}',
                serverName: 'Server ${sourceEpisode.number.toInt()}',
                initialUrl: Uri.parse(
                  'https://example.com/${sourceEpisode.number.toInt()}',
                ),
                linkType: SourceServerLinkType.stream,
              ),
            ]);
          },
      enqueueDownload:
          ({
            required int anilistId,
            required double episodeNumber,
            required SourceServerLink serverLink,
            required String sourcePluginId,
            String? animeTitle,
            String? coverImageUrl,
            String? episodeTitle,
          }) async {
            enqueuedEpisodes.add(episodeNumber);
            return const Success(null);
          },
    );

    final report = await service.enqueueEpisodes(
      anilistId: 7001,
      episodeNumbers: const <int>[2, 3],
      animeTitle: 'Test Anime',
    );

    expect(report.disabled, isFalse);
    expect(report.enqueuedEpisodes, 2);
    expect(report.failedEpisodes, 0);
    expect(report.missingSourceEpisodes, 0);
    expect(enqueuedEpisodes, <double>[2, 3]);
  });

  test('skips existing tasks and falls back from excluded source', () async {
    libraryStore.autoDownloadIds.add(8001);
    downloadStore.tasksByAnime[8001] = <DownloadTask>[
      DownloadTask(
        id: '8001-3',
        anilistId: 8001,
        episodeNumber: 3,
        sourceUrl: Uri.parse('https://example.com/3.mp4'),
        status: DownloadStatus.pending,
        createdAt: DateTime.now(),
        fileName: 'EP 03.mp4',
      ),
    ];

    final secondaryPlugin = _AutoDownloadTestSourcePlugin(
      pluginId: 'test.source.secondary',
      displayName: 'Secondary Source',
    );
    final secondCodec = SourceAvailabilityCacheCodec(
      sourcePlugins: <SourcePlugin>[plugin, secondaryPlugin],
      selectionPolicy: const SourceSelectionPolicy(),
    );
    sourceAvailabilityStore.values[8001] = secondCodec.encode(
      anilistId: 8001,
      updatedAt: DateTime.now(),
      summary: SourceAvailabilitySummary(
        sources: <SourceAvailability>[
          _sourceAvailability(
            'kumoriya.source.anime_nexus',
            'Anime Nexus',
            const <int>[2],
          ),
          _sourceAvailability(
            secondaryPlugin.manifest.id,
            secondaryPlugin.manifest.displayName,
            const <int>[2, 3],
          ),
        ],
        recommended: _sourceAvailability(
          'kumoriya.source.anime_nexus',
          'Anime Nexus',
          const <int>[2],
        ),
      ),
    );

    final usedSourceIds = <String>[];
    final service = AutoDownloadNewEpisodesService(
      libraryStore: libraryStore,
      downloadStore: downloadStore,
      sourceAvailabilityStore: sourceAvailabilityStore,
      sourceAvailabilityCacheCodec: secondCodec,
      sourcePlugins: <SourcePlugin>[plugin, secondaryPlugin],
      loadServerLinks:
          ({
            required SourcePlugin sourcePlugin,
            required SourceEpisode sourceEpisode,
          }) async {
            return Success(<SourceServerLink>[
              SourceServerLink(
                serverId: 'server-${sourceEpisode.number.toInt()}',
                serverName: 'Server ${sourceEpisode.number.toInt()}',
                initialUrl: Uri.parse(
                  'https://example.com/${sourcePlugin.manifest.id}/${sourceEpisode.number.toInt()}',
                ),
                linkType: SourceServerLinkType.stream,
              ),
            ]);
          },
      enqueueDownload:
          ({
            required int anilistId,
            required double episodeNumber,
            required SourceServerLink serverLink,
            required String sourcePluginId,
            String? animeTitle,
            String? coverImageUrl,
            String? episodeTitle,
          }) async {
            usedSourceIds.add(sourcePluginId);
            return const Success(null);
          },
      excludedSourcePluginId: 'kumoriya.source.anime_nexus',
    );

    final report = await service.enqueueEpisodes(
      anilistId: 8001,
      episodeNumbers: const <int>[2, 3],
    );

    expect(report.enqueuedEpisodes, 1);
    expect(report.alreadyQueuedEpisodes, 1);
    expect(usedSourceIds, <String>[secondaryPlugin.manifest.id]);
  });
}

final class _FakeLibraryStore implements LibraryStore {
  final Set<int> autoDownloadIds = <int>{};
  final Map<int, String> autoDownloadAudioPreferenceByAnime = <int, String>{};

  @override
  Future<String?> getAutoDownloadAudioPreference(int anilistId) async {
    return autoDownloadAudioPreferenceByAnime[anilistId] ?? 'none';
  }

  @override
  Future<void> setAutoDownloadAudioPreference(
    int anilistId,
    String preference,
  ) async {
    autoDownloadAudioPreferenceByAnime[anilistId] = preference;
  }

  @override
  Future<Result<Set<int>, KumoriyaError>> getAutoDownloadAnimeIds() async {
    return Success(autoDownloadIds);
  }

  @override
  Future<LibraryEntrySnapshot?> getEntrySnapshot(int anilistId) async {
    return LibraryEntrySnapshot(
      anilistId: anilistId,
      isFavorite: false,
      addedAt: null,
      notifyNewEpisodes: false,
      autoDownloadNewEpisodes: autoDownloadIds.contains(anilistId),
      autoDownloadAudioPreference:
          autoDownloadAudioPreferenceByAnime[anilistId] ?? 'none',
      lastNotifiedEpisode: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeDownloadStore implements DownloadStore {
  final Map<int, List<DownloadTask>> tasksByAnime = <int, List<DownloadTask>>{};

  @override
  Future<Result<List<DownloadTask>, KumoriyaError>> getTasksByAnime(
    int anilistId, {
    int? limit,
  }) async {
    return Success(tasksByAnime[anilistId] ?? const <DownloadTask>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeSourceAvailabilityStore implements SourceAvailabilityStore {
  final Map<int, List<SourceAvailabilityCacheRecord>> values =
      <int, List<SourceAvailabilityCacheRecord>>{};

  @override
  Future<Result<List<SourceAvailabilityCacheRecord>, KumoriyaError>>
  getAvailability(int anilistId) async {
    final value = values[anilistId];
    if (value == null) {
      return Failure(
        SimpleError(
          code: 'test.missing_availability',
          message: 'Missing availability for $anilistId',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    return Success(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SourceAvailabilitySummary _summary(String pluginId, List<int> episodes) {
  final source = _sourceAvailability(pluginId, 'Test Source', episodes);
  return SourceAvailabilitySummary(
    sources: <SourceAvailability>[source],
    recommended: source,
  );
}

SourceAvailability _sourceAvailability(
  String pluginId,
  String displayName,
  List<int> episodes,
) {
  return SourceAvailability(
    manifest: PluginManifest(
      id: pluginId,
      displayName: displayName,
      type: PluginType.source,
      capabilities: const <PluginCapability>{
        PluginCapability.search,
        PluginCapability.episodeList,
      },
    ),
    status: SourceAvailabilityStatus.available,
    decision: const SourceMatchDecision(
      verdict: true,
      confidence: MatchConfidence.high,
      reason: 'test',
      acceptanceSignals: <String>['test'],
      rejectionSignals: <String>[],
    ),
    episodes: episodes
        .map(
          (number) => SourceEpisode(
            sourceEpisodeId: '$pluginId-$number',
            number: number.toDouble(),
            title: 'Episode $number',
            episodeUrl: Uri.parse('https://example.com/$pluginId/$number'),
          ),
        )
        .toList(growable: false),
  );
}

final class _AutoDownloadTestSourcePlugin implements SourcePlugin {
  _AutoDownloadTestSourcePlugin({
    this.pluginId = 'test.source.auto_download',
    this.displayName = 'Auto Download Test Source',
  });

  final String pluginId;
  final String displayName;

  @override
  PluginManifest get manifest => PluginManifest(
    id: pluginId,
    displayName: displayName,
    type: PluginType.source,
    capabilities: const <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
    },
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) {
    throw UnimplementedError();
  }
}
