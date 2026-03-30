import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'get_available_recommendations_use_case.dart';
import 'recommendation_provider.dart';
import '../../source_availability/application/use_cases/load_source_availability_summary_use_case.dart';

part 'recommendation_providers.g.dart';

/// Provider para el RecommendationProvider externo (AniList, Jikan, etc)
final recommendationProviderProvider = Provider<RecommendationProvider>((ref) {
  throw UnimplementedError('Implementa el RecommendationProvider real');
});

/// Provider para el use case de recomendaciones disponibles
@riverpod
GetAvailableRecommendationsUseCase getAvailableRecommendationsUseCase(GetAvailableRecommendationsUseCaseRef ref) {
  final provider = ref.watch(recommendationProviderProvider);
  final getAvailability = ref.watch(loadSourceAvailabilitySummaryUseCaseProvider).call;
  return GetAvailableRecommendationsUseCase(
    provider: provider,
    getAvailability: getAvailability,
  );
}
