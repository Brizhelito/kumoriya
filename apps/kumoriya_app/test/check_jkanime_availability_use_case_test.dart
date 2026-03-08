import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/matching/anilist_jkanime_matcher.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/check_jkanime_availability_use_case.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  const matcher = AnilistJkanimeMatcher();

  test('returns unavailable noMatch when matcher rejects candidates', () async {
    final useCase = CheckJkanimeAvailabilityUseCase(
      sourcePlugin: _FakeSourcePluginNoMatch(),
      matcher: matcher,
    );

    final result = await useCase.call(_detail('Naruto'));

    expect(result.isSuccess, isTrue);
    result.fold(
      onFailure: (_) => fail('expected success'),
      onSuccess: (availability) {
        expect(availability.status, SourceAvailabilityStatus.unavailable);
        expect(availability.unavailableReason, SourceUnavailableReason.noMatch);
      },
    );
  });

  test(
    'returns unavailable noEpisodes when source has empty episodes',
    () async {
      final useCase = CheckJkanimeAvailabilityUseCase(
        sourcePlugin: _FakeSourcePluginNoEpisodes(),
        matcher: matcher,
      );

      final result = await useCase.call(_detail('Naruto'));

      expect(result.isSuccess, isTrue);
      result.fold(
        onFailure: (_) => fail('expected success'),
        onSuccess: (availability) {
          expect(availability.status, SourceAvailabilityStatus.unavailable);
          expect(
            availability.unavailableReason,
            SourceUnavailableReason.noEpisodes,
          );
        },
      );
    },
  );

  test('returns failure when source breaks during episodes fetch', () async {
    final useCase = CheckJkanimeAvailabilityUseCase(
      sourcePlugin: _FakeSourcePluginTransportFailure(),
      matcher: matcher,
    );

    final result = await useCase.call(_detail('Naruto'));

    expect(result.isFailure, isTrue);
    result.fold(
      onFailure: (error) => expect(error.kind, KumoriyaErrorKind.transport),
      onSuccess: (_) => fail('expected failure'),
    );
  });
}

AnimeDetail _detail(String title) {
  return AnimeDetail(
    anime: Anime(
      anilistId: 1,
      title: AnimeTitle(romaji: title),
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
        code: 'jkanime.empty',
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
        code: 'jkanime.transport',
        message: 'down',
        kind: KumoriyaErrorKind.transport,
      ),
    );
  }
}
