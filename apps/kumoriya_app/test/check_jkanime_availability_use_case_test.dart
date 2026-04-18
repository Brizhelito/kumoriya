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

  test(
    'adds TV season query variants for bare trailing number titles',
    () async {
      final plugin = _FakeSourcePluginBareTrailingSeasonQueryOnly();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 1,
            title: AnimeTitle(romaji: 'Boku no Hero Academia 7'),
            format: AnimeFormat.tv,
            releaseYear: 2025,
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(plugin.queries, contains('Boku no Hero Academia 7th Season'));
    },
  );

  test(
    'direct slug probe enriches sparse matches already returned by search',
    () async {
      final plugin = _FakeSourcePluginSparseSeasonMatchNeedsDetailProbe();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 1,
            title: AnimeTitle(romaji: 'Boku no Hero Academia 7'),
            format: AnimeFormat.tv,
            releaseYear: 2025,
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(plugin.queries, contains('Boku no Hero Academia 7'));
      expect(plugin.queries, contains('Boku no Hero Academia 7th Season'));
      expect(
        plugin.detailRequests,
        contains('boku-no-hero-academia-7th-season'),
      );
      expect(
        availability.matchedAnime?.sourceId,
        'boku-no-hero-academia-7th-season',
      );
    },
  );

  test(
    'direct slug probe expands bare trailing number TV titles to season slugs',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginBareTrailingSeasonSlugOnly(),
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 1,
            title: AnimeTitle(romaji: 'Boku no Hero Academia 7'),
            format: AnimeFormat.tv,
            releaseYear: 2025,
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(
        availability.matchedAnime?.sourceId,
        'boku-no-hero-academia-7th-season',
      );
    },
  );

  test(
    'accepts directly confirmed ONA titles when the source reports TV format drift',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginDirectOnaTvFormatBridge(),
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 191205,
            title: AnimeTitle(
              romaji: 'Okiraku Ryoushu no Tanoshii Ryouchi Bouei',
              english: 'Easygoing Territory Defense by the Optimistic Lord',
            ),
            format: AnimeFormat.ona,
            releaseYear: 2026,
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(
        availability.matchedAnime?.sourceId,
        'okiraku-ryoushu-no-tanoshii-ryouchi-bouei',
      );
    },
  );

  test(
    'accepts ONA/TV bridge via search-discovered candidate when short slug does not exist',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginSearchDiscoveredOnaTvBridge(),
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 191205,
            title: AnimeTitle(
              romaji: 'Okiraku Ryoushu no Tanoshii Ryouchi Bouei',
              english: 'Easygoing Territory Defense by the Optimistic Lord',
            ),
            format: AnimeFormat.ona,
            releaseYear: 2026,
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(
        availability.matchedAnime?.sourceId,
        'okiraku-ryoushu-no-tanoshii-ryouchi-bouei-seisankei-majutsu-de-na-mo-naki-mura-wo-saikyou-no-jousai-toshi-ni',
      );
      expect(
        availability.decision.acceptanceSignals,
        contains('direct-confirmed-ona-tv-bridge'),
      );
    },
  );

  test(
    'accepts directly confirmed strong title matches when the source format is unknown',
    () async {
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginSearchDiscoveredUnknownFormatBridge(),
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 191205,
            title: AnimeTitle(
              romaji: 'Okiraku Ryoushu no Tanoshii Ryouchi Bouei',
              english: 'Easygoing Territory Defense by the Optimistic Lord',
            ),
            format: AnimeFormat.ona,
            releaseYear: 2026,
          ),
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      expect(
        availability.decision.acceptanceSignals,
        contains('direct-confirmed-unknown-format-bridge'),
      );
    },
  );

  test(
    'adds supplemental alias for ganzo bandori direct confirmation',
    () async {
      final plugin = _FakeSourcePluginGanzoBandoriDirectOnly();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 187166,
            title: AnimeTitle(
              romaji: 'Ganso! Bandori-chan',
              english: 'GANSO! BanG Dream Chan',
              native: '元祖！バンドリちゃん',
            ),
            format: AnimeFormat.ona,
            releaseYear: 2025,
          ),
        ),
      );

      expect(plugin.detailRequests, contains('ganzo-bandori-chan'));
      expect(availability.status, SourceAvailabilityStatus.available);
      expect(availability.matchedAnime?.sourceId, 'ganzo-bandori-chan');
    },
  );

  test(
    'adds supplemental detective conan query when AniList detail lacks synonym payload',
    () async {
      final plugin = _FakeSourcePluginDetectiveConanAliasOnly();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 235,
            title: AnimeTitle(
              romaji: 'Meitantei Conan',
              english: 'Case Closed',
              native: '名探偵コナン',
            ),
            format: AnimeFormat.tv,
            releaseYear: 1996,
          ),
        ),
      );

      expect(plugin.queries, contains('Detective Conan'));
      expect(plugin.detailRequests, contains('detective-conan'));
      expect(availability.status, SourceAvailabilityStatus.available);
      expect(availability.matchedAnime?.sourceId, 'detective-conan');
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

  test(
    'grouped season alignment uses prequel episode count when source has '
    'more S2 episodes than AniList reports as aired',
    () async {
      // Regression: Otonari no Tenshi-sama S2 — AniList reported 2 aired
      // (nextAiringEpisode=3) while the source already listed 3 S2 episodes
      // under the grouped S1 slug (source.length = 12 + 3 = 15). The legacy
      // heuristic `source.sublist(length - aired)` dropped source_13
      // (= real S2_ep1) and aligned source_14 to displayed "ep1", so clicking
      // ep1 played ep2's content.
      final plugin = _FakeSourcePluginGroupedPrequelAware();
      final useCase = CheckSourceAvailabilityUseCase(
        sourcePlugin: plugin,
        matcher: matcher,
      );

      final availability = await useCase.call(
        AnimeDetail(
          anime: const Anime(
            anilistId: 999,
            title: AnimeTitle(romaji: 'Otonari no Tenshi-sama 2'),
            format: AnimeFormat.tv,
            totalEpisodes: 12,
            status: AnimeStatus.releasing,
          ),
          episodes: const <AnimeEpisode>[
            AnimeEpisode(number: 1, title: 'Episode 1', isAired: true),
            AnimeEpisode(number: 2, title: 'Episode 2', isAired: true),
            AnimeEpisode(number: 3, title: 'Episode 3', isAired: false),
          ],
          relations: const <AnimeRelation>[
            AnimeRelation(
              type: AnimeRelationType.prequel,
              anime: Anime(
                anilistId: 998,
                title: AnimeTitle(romaji: 'Otonari no Tenshi-sama'),
                format: AnimeFormat.tv,
                totalEpisodes: 12,
              ),
            ),
          ],
        ),
      );

      expect(availability.status, SourceAvailabilityStatus.available);
      // The alignment should start at source_13 (first S2 episode in the
      // grouped listing) and expose source_13 → displayed ep1.
      expect(
        availability.episodes
            .map((episode) => episode.sourceEpisodeId)
            .toList(),
        <String>['otonari_13', 'otonari_14', 'otonari_15'],
      );
      expect(
        availability.episodes.map((episode) => episode.number).toList(),
        <double>[1, 2, 3],
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
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'oshi-no-ko') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'oshi-no-ko',
          title: 'Oshi no Ko',
          format: AnimeFormat.tv,
          releaseYear: 2023,
          aliases: <String>['Oshi no Ko 2nd Season'],
          seasonNumber: 2,
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
        episodeUrl: Uri.parse('https://example.com/oshi/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginBareTrailingSeasonQueryOnly
    extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Boku no Hero Academia 7th Season') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'boku-no-hero-academia-7th-season',
          title: 'Boku no Hero Academia 7',
          format: AnimeFormat.tv,
          releaseYear: 2025,
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
        episodeUrl: Uri.parse('https://example.com/mha/7/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginSparseSeasonMatchNeedsDetailProbe
    extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];
  final List<String> detailRequests = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Boku no Hero Academia 7') {
      return Success(
        List<SourceAnimeMatch>.generate(
          10,
          (index) => SourceAnimeMatch(
            sourceId: 'mha-noise-$index',
            title: 'Boku no Hero Academia Noise $index',
            format: AnimeFormat.tv,
            releaseYear: 2025,
          ),
        ),
      );
    }

    if (query.query == 'Boku no Hero Academia 7th Season') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'boku-no-hero-academia-7th-season',
          title: 'Boku no Hero Academia 7th Season',
        ),
      ]);
    }

    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    detailRequests.add(sourceId);
    if (sourceId == 'boku-no-hero-academia-7th-season') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'boku-no-hero-academia-7th-season',
          title: 'Boku no Hero Academia 7th Season',
          format: AnimeFormat.tv,
          releaseYear: 2025,
          seasonNumber: 7,
          aliases: <String>['My Hero Academia Season 7'],
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
        episodeUrl: Uri.parse('https://example.com/mha/7/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginBareTrailingSeasonSlugOnly
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
    if (sourceId == 'boku-no-hero-academia-7th-season') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'boku-no-hero-academia-7th-season',
          title: 'Boku no Hero Academia 7',
          format: AnimeFormat.tv,
          releaseYear: 2025,
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
        episodeUrl: Uri.parse('https://example.com/mha/7/1'),
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
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'mushoku-tensei' || sourceId == 'mushoku-tensei-main') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'mushoku-tensei-main',
          title: 'Mushoku Tensei: Isekai Ittara Honki Dasu',
          format: AnimeFormat.tv,
          aliases: <String>[
            'Mushoku Tensei',
            'Mushoku Tensei: Isekai Ittara Honki Dasu - Megami ni Erabareshi',
          ],
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
        episodeUrl: Uri.parse('https://example.com/mushoku/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginDirectOnaTvFormatBridge
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
    if (sourceId == 'okiraku-ryoushu-no-tanoshii-ryouchi-bouei') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'okiraku-ryoushu-no-tanoshii-ryouchi-bouei',
          title:
              'Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
      );
    }

    if (sourceId == 'easygoing-territory-defense-by-the-optimistic-lord') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'okiraku-ryoushu-no-tanoshii-ryouchi-bouei',
          title:
              'Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City',
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
        episodeUrl: Uri.parse('https://example.com/okiraku/1'),
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
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'oshi-no-ko') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'oshi-no-ko',
          title: 'Oshi no Ko',
          format: AnimeFormat.tv,
          releaseYear: 2023,
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

final class _FakeSourcePluginGroupedPrequelAware extends _BaseFakeSourcePlugin {
  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    return const Success(<SourceAnimeMatch>[
      SourceAnimeMatch(
        sourceId: 'otonari-no-tenshi-sama',
        title: 'Otonari no Tenshi-sama',
        format: AnimeFormat.tv,
      ),
    ]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'otonari-no-tenshi-sama') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'otonari-no-tenshi-sama',
          title: 'Otonari no Tenshi-sama',
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
    // Source groups S1 (12 eps) + S2 (3 eps uploaded so far) = 15 episodes
    // under one umbrella slug.
    return Success(
      List<SourceEpisode>.generate(
        15,
        (index) => SourceEpisode(
          sourceEpisodeId: 'otonari_${index + 1}',
          number: (index + 1).toDouble(),
          title: 'Umbrella Episode ${index + 1}',
          episodeUrl: Uri.parse('https://example.com/otonari/${index + 1}'),
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
        aliases: <String>[
          'Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.',
        ],
      ),
    ]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId ==
        'yuusha-party-ni-kawaii-ko-ga-ita-node-kokuhaku-shitemita') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'yuusha-party-ni-kawaii-ko-ga-ita-node-kokuhaku-shitemita',
          title: 'Yuusha Party ni Kawaii Ko ga Ita node, Kokuhaku shitemita.',
          format: AnimeFormat.tv,
          aliases: <String>[
            'Yuusha Party ni Kawaii Ko ga Ita no de, Kokuhaku Shitemita.',
          ],
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
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'pokemon-shinsaku-anime' || sourceId == 'pokemon') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'pokemon-shinsaku-anime',
          title: 'Pokemon (Shinsaku Anime)',
          format: AnimeFormat.tv,
          aliases: <String>[
            'Pokémon Horizons: The Series',
            'Pocket Monsters (2023)',
            'Pokémon (2023)',
          ],
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
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'hell-mode') {
      return const Success(
        SourceAnimeDetail(
          sourceId:
              'hell-mode-yarikomizuki-no-gamer-wa-hai-settei-no-isekai-de-musou-suru',
          title:
              'Hell Mode: Yarikomizuki no Gamer wa Hai Settei no Isekai de Musou suru',
          format: AnimeFormat.tv,
          releaseYear: 2026,
          aliases: <String>[
            'Hell Mode: Yarikomi Suki no Gamer wa Haisettei no Isekai de Musou Suru',
          ],
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
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == 'dark-moon-tsuki-no-saidan') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'dark-moon-tsuki-no-saidan',
          title: 'Dark Moon: Tsuki no Saidan',
          format: AnimeFormat.tv,
          releaseYear: 2026,
          aliases: <String>['DARK MOON: Kuro no Tsuki - Tsuki no Saidan'],
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

/// Search returns the long-titled candidate but the short AniList slug does
/// not resolve. The use case should probe the search result's own sourceId,
/// confirm the entry, and accept it through the ONA/TV bridge.
final class _FakeSourcePluginSearchDiscoveredOnaTvBridge
    extends _BaseFakeSourcePlugin {
  static const _longSlug =
      'okiraku-ryoushu-no-tanoshii-ryouchi-bouei-seisankei-majutsu-de-na-mo-naki-mura-wo-saikyou-no-jousai-toshi-ni';

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    final lower = query.query.toLowerCase();
    if (lower.contains('okiraku') || lower.contains('easygoing')) {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: _longSlug,
          title:
              'Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni',
          format: AnimeFormat.tv,
          releaseYear: 2026,
        ),
      ]);
    }
    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == _longSlug) {
      return const Success(
        SourceAnimeDetail(
          sourceId: _longSlug,
          title:
              'Okiraku Ryoushu no Tanoshii Ryouchi Bouei: Seisankei Majutsu de Na mo Naki Mura wo Saikyou no Jousai Toshi ni',
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
    if (sourceId == _longSlug) {
      return Success(<SourceEpisode>[
        SourceEpisode(
          sourceEpisodeId: 'ep1',
          number: 1,
          title: 'Episode 1',
          episodeUrl: Uri.parse('https://example.com/okiraku/1'),
        ),
      ]);
    }
    return const Success(<SourceEpisode>[]);
  }
}

final class _FakeSourcePluginSearchDiscoveredUnknownFormatBridge
    extends _BaseFakeSourcePlugin {
  static const _encodedSourceId =
      '9ede6265-c9b9-47bf-bfb5-7e340223708e::easygoing-territory-defense-by-the-optimistic-lord-production-magic-turns-a-nameless-village-into-the-strongest-fortified-city-0504b068c520f15a4965';

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    final lower = query.query.toLowerCase();
    if (lower.contains('easygoing') || lower.contains('okiraku')) {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: _encodedSourceId,
          title:
              'Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City',
          format: AnimeFormat.unknown,
          releaseYear: 2026,
        ),
      ]);
    }
    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    if (sourceId == _encodedSourceId) {
      return const Success(
        SourceAnimeDetail(
          sourceId: _encodedSourceId,
          title:
              'Easygoing Territory Defense by the Optimistic Lord: Production Magic Turns a Nameless Village into the Strongest Fortified City',
          format: AnimeFormat.unknown,
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
    if (sourceId == _encodedSourceId) {
      return Success(<SourceEpisode>[
        SourceEpisode(
          sourceEpisodeId: 'ep1',
          number: 1,
          title: 'Episode 1',
          episodeUrl: Uri.parse('https://example.com/anime-nexus/okiraku/1'),
        ),
      ]);
    }
    return const Success(<SourceEpisode>[]);
  }
}

final class _FakeSourcePluginGanzoBandoriDirectOnly
    extends _BaseFakeSourcePlugin {
  final List<String> detailRequests = <String>[];

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
    detailRequests.add(sourceId);
    if (sourceId == 'ganzo-bandori-chan') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'ganzo-bandori-chan',
          title: 'Ganzo! Bandori-chan',
          format: AnimeFormat.ona,
          releaseYear: 2025,
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
        episodeUrl: Uri.parse('https://example.com/bandori/1'),
      ),
    ]);
  }
}

final class _FakeSourcePluginDetectiveConanAliasOnly
    extends _BaseFakeSourcePlugin {
  final List<String> queries = <String>[];
  final List<String> detailRequests = <String>[];

  @override
  Future<Result<List<SourceAnimeMatch>, KumoriyaError>> search(
    SourceSearchQuery query,
  ) async {
    queries.add(query.query);
    if (query.query == 'Detective Conan') {
      return const Success(<SourceAnimeMatch>[
        SourceAnimeMatch(
          sourceId: 'detective-conan-special',
          title: 'Detective Conan Special',
          format: AnimeFormat.tv,
          releaseYear: 2012,
        ),
      ]);
    }

    return const Success(<SourceAnimeMatch>[]);
  }

  @override
  Future<Result<SourceAnimeDetail, KumoriyaError>> getAnimeDetail(
    String sourceId,
  ) async {
    detailRequests.add(sourceId);
    if (sourceId == 'detective-conan') {
      return const Success(
        SourceAnimeDetail(
          sourceId: 'detective-conan',
          title: 'Detective Conan',
          format: AnimeFormat.tv,
          releaseYear: 1996,
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
        episodeUrl: Uri.parse('https://example.com/conan/1'),
      ),
    ]);
  }
}
