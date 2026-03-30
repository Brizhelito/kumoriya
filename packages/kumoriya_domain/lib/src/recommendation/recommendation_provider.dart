/// Contrato para proveedores de recomendaciones externas (AniList, Jikan, etc)
/// Devuelve una lista de AniList IDs recomendados para un anime dado.
abstract class RecommendationProvider {
  /// [animeId] es el AniList ID del anime base.
  /// [limit] es el máximo de recomendaciones a pedir (opcional).
  Future<List<int>> fetchRecommendations({required int animeId, int? limit});
}
