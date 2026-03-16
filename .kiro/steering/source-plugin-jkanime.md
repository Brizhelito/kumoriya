---
inclusion: always
---

# Source Plugin JKAnime (Kumoriya)

Implementa solo comportamiento del source plugin de JKAnime. Mantén el scope ajustado, el parser robusto y los tests reales.

## Cuándo activar este skill

Úsalo cuando:
- Trabajes en search, minimal detail, episode listing o lógica de parsing de JKAnime
- Endurezcas parsers con fixtures o corrijas regresiones de scraping
- Valides cumplimiento de contratos del source plugin
- Documentes limitaciones conocidas del plugin

## Restricciones absolutas

1. AniList es la fuente canónica de metadatos.
2. Limitar trabajo a responsabilidades del source plugin: search, minimal detail, real episodes, lógica de parsing.
3. Excluir playback y resolvers.
4. Preferir no-match/no-data sobre resultados débilmente inferidos.
5. Mantener source plugins independientes de resolver plugins.

## Bloque de scope (publicar antes de codificar)

```md
JKAnime Slice Scope
- Request:
- In scope:
- Out of scope (must include playback/resolvers):
- Done when:
```

Si el usuario pide scope mixto, dividir e implementar solo la parte del source plugin.

## Revisión de contratos del source plugin

```md
Contract Review
- interface/model:
- required fields:
- parser source:
- failure behavior:
```

1. Localizar interfaces y modelos plugin-facing usados por el paquete source de JKAnime.
2. Confirmar campos requeridos e invariantes para: search result item, anime detail (minimal), episode entries.
3. Mantener mapping explícito de campos raw de JKAnime al modelo de contrato.
4. Si datos de JKAnime son faltantes/ambiguos, retornar empty/none con error tipado o fallback seguro definido por contrato.

## Scraping robusto y parsing defensivo

1. Preferir anchors semánticos (patrones de URL, atributos estables, labels de sección) sobre cadenas nth-child frágiles.
2. Normalizar texto antes de comparaciones (trim, whitespace collapse, case folding, normalización de puntuación).
3. Parsear defensivamente: guard null/empty nodes, validar extracción de URL/id, evitar throw en bloques opcionales.
4. Preservar comportamiento determinista ante cambios parciales de HTML.
5. Mantener funciones de parser pequeñas y testeables; separar fetch de parse donde sea práctico.

## Política de fixtures para JKAnime

```md
Fixture Plan
- fixture file:
- source page type:
- scenario covered:
```

Capturar HTML representativo para: search page, anime detail page, episode listing page.
Agregar fixtures enfocadas para edge cases conocidos: poster faltante, título alternativo, markup de episodio inusual.

## Tests requeridos (enfocados en plugin)

Tests mínimos:
1. Test de parsing de search: query válida retorna items mapeados esperados; inputs débiles/ambiguos pueden retornar empty de forma segura.
2. Test de parsing de detail: campos mínimos requeridos parseados; bloques opcionales faltantes no crashean.
3. Test de parsing de episodes: extrae episodios reales ordenados desde fixture; nodos malformados se omiten de forma segura.
4. Test de plugin a nivel integración (si el repo lo tiene): método del source plugin retorna objetos válidos según contrato.

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze <affected package>
- [ ] dart test <plugin package or targeted tests>
```

No declarar completitud sin comandos ejecutados y resultados observados.

## Logging de limitaciones

```md
Plugin Limitations
- limitation:
- impact:
- mitigation:
```

Documentar: qué no puede garantizarse (volatilidad de selectores, metadata faltante, comportamiento anti-bot), qué fallbacks existen, qué retorna intencionalmente no-match/no-data.

## Plantilla de reporte final

```md
JKAnime Plugin Report
- Scope executed:
- Contracts touched:
- Files changed:
- Fixtures added/updated:
- Tests run:
  - command:
  - result:
- Limitations documented:
- Residual risk:
```
