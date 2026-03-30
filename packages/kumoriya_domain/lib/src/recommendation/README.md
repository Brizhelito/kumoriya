# Kumoriya Recommendation Slice

## Overview
Este slice implementa un pipeline de recomendaciones aware de availability real:
- Genera candidatos usando un RecommendationProvider externo (AniList, Jikan, etc).
- Filtra solo los que tienen sources reproducibles en Kumoriya (playableSources).

## Estructura
- `recommendation_provider.dart`: Contrato para proveedores externos.
- `get_available_recommendations_use_case.dart`: Use case que filtra recomendaciones por availability local.
- `recommendation_providers.dart`: Providers Riverpod para inyectar dependencias.
- `test/recommendation/get_available_recommendations_use_case_test.dart`: Test de integración básica.

## Extensión
- Implementa un RecommendationProvider real para AniList/Jikan.
- Usa el provider y use case en la UI para Home, detalles, etc.

## Garantías
- Nunca recomienda anime sin sources reproducibles.
- Modular, testable, y desacoplado de la UI y de providers concretos.
