import '../source_availability/models/source_availability.dart';
import 'recommendation_provider.dart';

/// Use case: Dado un animeId, obtiene recomendaciones externas y filtra por availability local.
class GetAvailableRecommendationsUseCase {
  final RecommendationProvider provider;
  final Future<SourceAvailabilitySummary?> Function(int animeId) getAvailability;

  GetAvailableRecommendationsUseCase({
    required this.provider,
    required this.getAvailability,
  });

  /// Devuelve solo los AniList IDs de recomendaciones con sources reproducibles.
  Future<List<int>> call({required int animeId, int? limit}) async {
    final candidates = await provider.fetchRecommendations(animeId: animeId, limit: limit);
    final available = <int>[];
    for (final id in candidates) {
      final summary = await getAvailability(id);
      if (summary != null && summary.playableSources.isNotEmpty) {
        available.add(id);
      }
    }
    return available;
  }
}
