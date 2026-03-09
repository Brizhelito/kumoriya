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
    'direct slug probe rescues titles when search misses the canonical entry',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginDirectSlugOnly(),
        matcher: matcher,
      );

      final availability = await useCase.call(_detail('One Piece'));

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(availability.matchedAnime?.sourceId, 'one-piece-tv');
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

  test(
    'adds stripped parenthetical and franchise queries for pokemon 2023',
    () async {
      final plugin = _FakeSourcePluginPokemonAliasSearch();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        _detail(
          'Pocket Monsters (2023)',
          titleOverride: const AnimeTitle(
            romaji: 'Pocket Monsters (2023)',
            english: 'Pokémon Horizons: The Series',
            synonyms: <String>['Pokémon (2023)'],
          ),
        ),
      );

      expect(plugin.queries, contains('Pokémon Horizons: The Series'));
      expect(plugin.queries, contains('Pokémon'));
      expect(availability.status, SourceAvailabilityStatus.available);
      expect(availability.matchedAnime?.sourceId, 'pokemon-shinsaku-anime');
    },
  );

  test('adds root title query for short colon titles like hell mode', () async {
    final plugin = _FakeSourcePluginHellModeRootOnly();
    final useCase = CheckSourceAvailabilityUseCase(
      sourcePlugin: plugin,
      matcher: matcher,
    );

    final availability = await useCase.call(
      _detail(
        'Hell Mode: Yarikomi Suki no Gamer wa Haisettei no Isekai de Musou Suru',
        titleOverride: const AnimeTitle(
          romaji:
              'Hell Mode: Yarikomi Suki no Gamer wa Haisettei no Isekai de Musou Suru',
        ),
      ),
    );

    expect(plugin.queries, contains('Hell Mode'));
    expect(availability.status, SourceAvailabilityStatus.available);
  });

  test(
    'adds root plus suffix query for omitted middle subtitle segments',
    () async {
      final plugin = _FakeSourcePluginDarkMoonRootSuffixOnly();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        _detail(
          'DARK MOON: Kuro no Tsuki - Tsuki no Saidan',
          titleOverride: const AnimeTitle(
            romaji: 'DARK MOON: Kuro no Tsuki - Tsuki no Saidan',
          ),
        ),
      );

      expect(plugin.queries, contains('DARK MOON'));
      expect(plugin.queries, contains('DARK MOON: Tsuki no Saidan'));
      expect(availability.status, SourceAvailabilityStatus.available);
    },
  );

  test(
    'builds ordinal season slug variants for season number titles',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginDouseOrdinalSlugOnly(),
        matcher: matcher,
      );

      final availability = await useCase.call(
        _detail(
          'Douse, Koishite Shimaunda. Season 2',
          titleOverride: const AnimeTitle(
            romaji: 'Douse, Koishite Shimaunda. Season 2',
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(
        availability.matchedAnime?.sourceId,
        'douse-koishite-shimaunda-2nd-season',
      );
    },
  );

  test('romanized no-de source title is accepted as mapped anime', () async {
    final useCase = CheckSourceAvailabilityUseCase(
      sourcePlugin: _FakeSourcePluginNodeVariant(),
      matcher: matcher,
    );

    final availability = await useCase.call(
      _detail('Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.'),
    );

    expect(availability.status, SourceAvailabilityStatus.available);
    expect(
      availability.matchedAnime?.sourceId,
      'yuusha-party-ni-kawaii-ko-ga-ita-node-kokuhaku-shitemita',
    );
  });

  test(
    'grouped season match aligns umbrella episodes to current season',
    () async {
      final plugin = _FakeSourcePluginGroupedSeasonEpisodes();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 77,
            title: AnimeTitle(romaji: 'Oshi no Ko 2nd Season'),
            format: AnimeFormat.tv,
            totalEpisodes: 13,
            status: AnimeStatus.releasing,
          ),
          episodes: const <AnimeEpisode>[
            AnimeEpisode(number: 1, title: 'Episode 1', isAired: true),
            AnimeEpisode(number: 2, title: 'Episode 2', isAired: true),
            AnimeEpisode(number: 3, title: 'Episode 3', isAired: false),
          ],
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(availability.episodes, hasLength(2));
      expect(
        availability.episodes.map((episode) => episode.number).toList(),
        <double>[1, 2],
      );
      expect(
        availability.episodes
            .map((episode) => episode.sourceEpisodeId)
            .toList(),
        <String>['oshi-no-ko_12', 'oshi-no-ko_13'],
      );
    },
  );
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

final class _FakeSourcePluginDirectSlugOnly extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(
        sourceId: 'one-piece-film-red',
        title: 'One Piece Film: Red',
        format: AnimeFormat.movie,
      ),
    ]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'one-piece-tv') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'one-piece-tv',
          title: 'One Piece',
          format: AnimeFormat.tv,
        ),
      );
    }

    return const Failure(
      SimpleError(
        code: 'source.not-found',
        message: 'not found',
        kind: KumoriyaErrorKind.notFound,
      ),
    );
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

final class _FakeSourcePluginGroupedSeasonEpisodes
    extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
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
    return Success(
      List<SourceEpisode>.generate(
        13,
        (index) => SourceEpisode(
          sourceEpisodeId: 'oshi-no-ko_${index + 1}',
          number: (index + 1).toDouble(),
          title: 'Umbrella Episode ${index + 1}',
          episodeUrl: Uri.parse('https://example.com/oshi/${index + 1}'),
        ),
      ),
    );
  }
}

final class _FakeSourcePluginNodeVariant extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(
        sourceId: 'yuusha-party-ni-kawaii-ko-ga-ita-node-kokuhaku-shitemita',
        title: 'Yuusha Party ni Kawaii Ko ga Ita node, Kokuhaku shitemita.',
        format: AnimeFormat.tv,
      ),
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

final class _FakeSourcePluginPokemonAliasSearch extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Pokémon Horizons: The Series') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'pokemon-shinsaku-anime',
          title: 'Pokemon (Shinsaku Anime)',
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
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginHellModeRootOnly extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Hell Mode') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId:
              'hell-mode-yarikomizuki-no-gamer-wa-hai-settei-no-isekai-de-musou-suru',
          title:
              'Hell Mode: Yarikomizuki no Gamer wa Hai Settei no Isekai de Musou suru',
          format: AnimeFormat.tv,
          releaseYear: 2026,
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
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginDarkMoonRootSuffixOnly
    extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'DARK MOON: Tsuki no Saidan') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'dark-moon-tsuki-no-saidan',
          title: 'Dark Moon: Tsuki no Saidan',
          format: AnimeFormat.tv,
          releaseYear: 2026,
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
        episodeUrl: Uri.parse('https://example.com/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginDouseOrdinalSlugOnly
    extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'douse-koishite-shimaunda-2nd-season') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'douse-koishite-shimaunda-2nd-season',
          title: 'Douse, Koishite Shimaunda. 2nd Season',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
      );
    }

    return const Failure(
      SimpleError(
        code: 'source.not-found',
        message: 'not found',
        kind: KumoriyaErrorKind.notFound,
      ),
    );
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
