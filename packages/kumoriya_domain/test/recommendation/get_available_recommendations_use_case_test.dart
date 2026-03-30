import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_domain/src/recommendation/get_available_recommendations_use_case.dart';
import 'package:kumoriya_domain/src/recommendation/recommendation_provider.dart';
import 'package:kumoriya_domain/src/source_availability/models/source_availability.dart';

class FakeRecommendationProvider implements RecommendationProvider {
  @override
  Future<List<int>> fetchRecommendations({required int animeId, int? limit}) async {
    return [1, 2, 3, 4];
  }
}

void main() {
  test('GetAvailableRecommendationsUseCase filtra por playableSources', () async {
    final provider = FakeRecommendationProvider();
    final getAvailability = (int id) async =>
      id % 2 == 0
        ? SourceAvailabilitySummary(playableSources: ['ok'], status: SourceAvailabilityStatus.available)
        : SourceAvailabilitySummary(playableSources: [], status: SourceAvailabilityStatus.unavailable);
    final useCase = GetAvailableRecommendationsUseCase(provider: provider, getAvailability: getAvailability);
    final result = await useCase.call(animeId: 123);
    expect(result, [2, 4]);
  });
}
