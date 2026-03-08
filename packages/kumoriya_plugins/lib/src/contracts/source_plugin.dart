import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../models/plugin_manifest.dart';

final class SourceSearchQuery {
  const SourceSearchQuery({
    required this.query,
    this.page = 1,
    this.limit = 20,
  });

  final String query;
  final int page;
  final int limit;
}

final class SourceAnimeMatch {
  const SourceAnimeMatch({
    required this.sourceId,
    required this.title,
    this.thumbnailUrl,
    this.releaseYear,
    this.format = AnimeFormat.unknown,
  });

  final String sourceId;
  final String title;
  final Uri? thumbnailUrl;
  final int? releaseYear;
  final AnimeFormat format;
}

final class SourceAnimeDetail {
  const SourceAnimeDetail({
    required this.sourceId,
    required this.title,
    this.synopsis,
    this.thumbnailUrl,
    this.releaseYear,
    this.format = AnimeFormat.unknown,
  });

  final String sourceId;
  final String title;
  final String? synopsis;
  final Uri? thumbnailUrl;
  final int? releaseYear;
  final AnimeFormat format;
}

final class SourceEpisode {
  const SourceEpisode({
    required this.sourceEpisodeId,
    required this.number,
    required this.title,
    required this.episodeUrl,
    this.thumbnailUrl,
  });

  final String sourceEpisodeId;
  final double number;
  final String title;
  final Uri episodeUrl;
  final Uri? thumbnailUrl;
}

abstract interface class SourcePlugin {
  PluginManifest get manifest;

  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  );

  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  );

  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  );
}
