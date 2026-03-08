import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

final class GetHomeCatalogUseCase {
  const GetHomeCatalogUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call() {
    return _repository.fetchHomeCatalog();
  }
}

final class SearchAnimeUseCase {
  const SearchAnimeUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<Anime>, KumoriyaError>> call(String query) {
    return _repository.searchAnime(AnimeSearchRequest(query: query));
  }
}

final class GetAnimeDetailUseCase {
  const GetAnimeDetailUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<AnimeDetail, KumoriyaError>> call(int anilistId) {
    return _repository.fetchAnimeDetail(anilistId);
  }
}

final class GetAnimeEpisodesUseCase {
  const GetAnimeEpisodesUseCase(this._repository);

  final AnimeCatalogRepository _repository;

  Future<Result<List<AnimeEpisode>, KumoriyaError>> call(int anilistId) {
    return _repository.fetchAnimeEpisodes(anilistId);
  }
}
