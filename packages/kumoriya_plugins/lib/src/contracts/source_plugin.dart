import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../models/plugin_manifest.dart';

final class SourceSearchQuery {
  const SourceSearchQuery({required this.query, this.limit = 20});

  final String query;
  final int limit;
}

final class SourceAnimeMatch {
  const SourceAnimeMatch({
    required this.sourceId,
    required this.title,
    this.thumbnailUrl,
  });

  final String sourceId;
  final String title;
  final Uri? thumbnailUrl;
}

abstract interface class SourcePlugin {
  PluginManifest get manifest;

  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  );

  Future<Result<AnimeDetail, KumoriyaError>> getAnimeDetail(String sourceId);

  Future<Result<List<AnimeEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  );
}
