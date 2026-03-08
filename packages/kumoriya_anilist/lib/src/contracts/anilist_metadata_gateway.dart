import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

abstract interface class AnilistMetadataGateway {
  Future<Result<List<Anime>, KumoriyaError>> searchAnime(String query);

  Future<Result<AnimeDetail, KumoriyaError>> getAnimeDetail(int anilistId);
}
