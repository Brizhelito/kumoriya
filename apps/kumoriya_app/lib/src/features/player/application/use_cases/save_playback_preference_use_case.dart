import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

final class SavePlaybackPreferenceUseCase {
  const SavePlaybackPreferenceUseCase({required AnimeProgressStore store})
    : _store = store;

  final AnimeProgressStore _store;

  Future<Result<void, KumoriyaError>> call({
    required int anilistId,
    required String sourcePluginId,
    required String serverName,
    required String resolverPluginId,
    PlaybackAudioPreference? preferredAudioPreference,
  }) {
    return _store.upsertPlaybackPreference(
      PlaybackPreference(
        anilistId: anilistId,
        preferredSourcePluginId: sourcePluginId,
        preferredServerName: serverName,
        preferredResolverPluginId: resolverPluginId,
        preferredAudioPreference: preferredAudioPreference,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
