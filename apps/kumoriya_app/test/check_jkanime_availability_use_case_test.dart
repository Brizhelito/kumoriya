import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_source_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/check_source_availability_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  const matcher = AnilistSourceMatcher();

  test('returns unavailable noMatch when matcher rejects candidates', () async {
    final useCase = CheckSourceAvailabilityUseCase(
      sourcePlugin: _FakeSourcePluginNoMatch(),
      matcher: matcher,
    );

    final availability = await useCase.call(_detail('Naruto'));

    expect(availability.status, SourceAvailabilityStatus.unavailable);
    expect(availability.unavailableReason, SourceUnavailableReason.noMatch);
  });

  test(
    'returns unavailable noEpisodes when source has empty episodes',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginNoEpisodes(),
        matcher: matcher,
      );

      final availability = await useCase.call(_detail('Naruto'));

      expect(availability.status, SourceAvailabilityStatus.unavailable);
      expect(
        availability.unavailableReason,
        SourceUnavailableReason.noEpisodes,
      );
    },
  );

  test(
    'returns error status when source breaks during episodes fetch',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginTransportFailure(),
        matcher: matcher,
      );

      final availability = await useCase.call(_detail('Naruto'));

      expect(availability.status, SourceAvailabilityStatus.error);
      expect(availability.errorMessage, contains('down'));
    },
  );

  test(
    'aggregates alternative AniList titles across multiple searches',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginAliasOnly(),
        matcher: matcher,
      );

      final availability = await useCase.call(
        _detail(
          'Kimetsu no Yaiba',
          titleOverride: const AnimeTitle(
            romaji: 'Kimetsu no Yaiba',
            english: 'Demon Slayer',
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(availability.matchedAnime?.sourceId, 'demon-slayer');
    },
  );

  test(
    'strips season descriptors from search queries before matching',
    () async {
      final plugin = _FakeSourcePluginSeasonRootOnly();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        _detail(
          'Oshi no Ko 2nd Season',
          titleOverride: const AnimeTitle(romaji: 'Oshi no Ko 2nd Season'),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(plugin.queries, contains('Oshi no Ko'));
      expect(availability.matchedAnime?.sourceId, 'oshi-no-ko');
    },
  );

  test('adds franchise root query for subtitle-heavy titles', () async {
    final plugin = _FakeSourcePluginFranchiseRootOnly();
    final useCase = CheckSourceAvailabilityUseCase(
      sourcePlugin: plugin,
      matcher: matcher,
    );

    final availability = await useCase.call(
      _detail(
        'Mushoku Tensei: Isekai Ittara Honki Dasu - Megami ni Erabareshi',
        titleOverride: const AnimeTitle(
          romaji:
              'Mushoku Tensei: Isekai Ittara Honki Dasu - Megami ni Erabareshi',
        ),
      ),
    );

    expect(availability.status, SourceAvailabilityStatus.available);
    expect(plugin.queries, contains('Mushoku Tensei'));
    expect(availability.matchedAnime?.sourceId, 'mushoku-tensei-main');
  });
}

AnimeDetail _detail(String title, {AnimeTitle? titleOverride}) {
  return AnimeDetail(
    anime: Anime(
      anilistId: 1,
      title: titleOverride ?? AnimeTitle(romaji: title),
      format: AnimeFormat.tv,
    ),
  );
}

class _BaseFakeSourcePlugin implements SourcePlugin {
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'fake.source',
    displayName: 'Fake Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{
      PluginCapability.search,
      PluginCapability.episodeList,
    },
  );

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceServerLink>, KumoriyaError>> getEpisodeServerLinks(
    SourceEpisode episode,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'naruto', title: 'Naruto'),
    ]);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    throw UnimplementedError();
  }
}

final class _FakeSourcePluginNoMatch extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'boruto', title: 'Boruto'),
    ]);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return const Success(<SourceEpisode>[]);
  }
}

final class _FakeSourcePluginNoEpisodes extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return const Failure(
      SimpleError(
        code: 'source.empty',
        message: 'no episodes',
        kind: KumoriyaErrorKind.notFound,
      ),
    );
  }
}

final class _FakeSourcePluginTransportFailure extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return const Failure(
      SimpleError(
        code: 'source.transport',
        message: 'down',
        kind: KumoriyaErrorKind.transport,
      ),
    );
  }
}

final class _FakeSourcePluginAliasOnly extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    if (query.query == 'Kimetsu no Yaiba') {
      return const Success(<SourceAnimeMatch>[]);
    }

    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(sourceId: 'demon-slayer', title: 'Demon Slayer'),
    ]);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: 'ep1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginSeasonRootOnly extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Oshi no Ko') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'oshi-no-ko',
          title: 'Oshi no Ko',
          format: AnimeFormat.tv,
          releaseYear: 2023,
        ),
      ]);
    }

    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: 'ep1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/oshi/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginFranchiseRootOnly extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Mushoku Tensei') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'mushoku-tensei-main',
          title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
          format: AnimeFormat.tv,
        ),
        SourceAnimeMatch(
          sourceId: 'mushoku-tensei-s2',
          title: 'Mushoku Tensei: Isekai Ittara Honki Dasu 2nd Season',
          format: AnimeFormat.tv,
        ),
      ]);
    }

    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<List<SourceEpisode>, KumoriyaError>> getEpisodes(
    String sourceId,
  ) async {
    return Success(<SourceEpisode>[
      SourceEpisode(
        sourceEpisodeId: 'ep1',
        number: 1,
        title: 'Episode 1',
        episodeUrl: Uri.parse('https://example.com/mushoku/1'),
      ),
    ]);
  }
}
