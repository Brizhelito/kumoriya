import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

final class ClearPlaybackPreferenceUseCase {
  const ClearPlaybackPreferenceUseCase({required AnimeProgressStore store})
    : _store = store;

  final AnimeProgressStore _store;

  Future<Result<void, KumoriyaError>> call(int anilistId) {
    return _store.clearPlaybackPreference(anilistId);
  }
}
