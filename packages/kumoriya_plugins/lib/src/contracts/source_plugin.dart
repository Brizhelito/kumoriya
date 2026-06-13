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
    this.aliases = const <String>[],
    this.totalEpisodes,
    this.seasonNumber,
    this.partNumber,
  });

  final String sourceId;
  final String title;
  final Uri? thumbnailUrl;
  final int? releaseYear;
  final AnimeFormat format;
  final List<String> aliases;
  final int? totalEpisodes;
  final int? seasonNumber;
  final int? partNumber;
}

final class SourceAnimeDetail {
  const SourceAnimeDetail({
    required this.sourceId,
    required this.title,
    this.synopsis,
    this.thumbnailUrl,
    this.releaseYear,
    this.format = AnimeFormat.unknown,
    this.aliases = const <String>[],
    this.totalEpisodes,
    this.seasonNumber,
    this.partNumber,
  });

  final String sourceId;
  final String title;
  final String? synopsis;
  final Uri? thumbnailUrl;
  final int? releaseYear;
  final AnimeFormat format;
  final List<String> aliases;
  final int? totalEpisodes;
  final int? seasonNumber;
  final int? partNumber;
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

final class ExternalSubtitleTrack {
  const ExternalSubtitleTrack({
    required this.id,
    required this.label,
    this.language,
    this.uri,
    this.data,
    this.isDefault = false,
  }) : assert(
         uri != null || data != null,
         'ExternalSubtitleTrack requires a uri or data payload.',
       );

  final String id;
  final String label;
  final String? language;
  final Uri? uri;
  final String? data;
  final bool isDefault;
}

enum SourceServerLinkType { stream, download }

final class SourceServerLink {
  const SourceServerLink({
    required this.serverId,
    required this.serverName,
    required this.initialUrl,
    this.language,
    this.linkType = SourceServerLinkType.stream,
    this.detectedHost,
    this.externalSubtitles = const <ExternalSubtitleTrack>[],
    this.isDirectStream = false,
  });

  final String serverId;
  final String serverName;
  final Uri initialUrl;
  final String? language;
  final SourceServerLinkType linkType;
  final String? detectedHost;
  final List<ExternalSubtitleTrack> externalSubtitles;
  final bool isDirectStream;
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

  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  );
}
