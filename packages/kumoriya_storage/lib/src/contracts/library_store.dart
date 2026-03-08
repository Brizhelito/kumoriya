import 'package:kumoriya_core/kumoriya_core.dart';

abstract interface class LibraryStore {
  Future<Result<void, KumoriyaError>> setFavorite(
    int anilistId, {
    required bool isFavorite,
  });

  Future<Result<Set<int>, KumoriyaError>> getFavoriteAnimeIds();
}
