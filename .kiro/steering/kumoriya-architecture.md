---
inclusion: always
---

# Kumoriya Architecture (Guardrails)

Enforces structural decisions for packages, boundaries, plugin contracts, and vertical slice scope.

## Cuándo activar este skill

Úsalo cuando:
- Tomes o revises decisiones estructurales sobre paquetes de Kumoriya
- Evalúes si un cambio cruza un límite de capa o paquete
- Definas o modifiques contratos de plugins
- Determines el scope de un vertical slice antes de implementarlo

## Restricciones absolutas

1. Monolito modular feature-first. No microservicios prematuros.
2. Riverpod para estado y DI. No singletons globales que bypaseen DI.
3. Result/Either para manejo de errores en boundaries domain/application/plugin.
4. UI no depende de implementaciones concretas de plugins.
5. Contratos de plugins viven en paquetes plugin-facing, no en paquetes UI.
6. Domain models limpios y framework-light.
7. Storage es una concern separada.
8. El player no resuelve links.
9. Los resolvers son independientes e individualmente testeables.
10. WebView es infraestructura de último recurso, no primitiva UX visible.

## Checklist de revisión arquitectónica

1. Identificar paquetes tocados.
2. Confirmar si el cambio cruza un boundary.
3. Rechazar coupling innecesario.
4. Preferir contratos explícitos.
5. Mantener slices verticales y revisables.
6. Declarar explícitamente qué se deja fuera intencionalmente.

## Separación de responsabilidades por capa

```
presentation     → widgets, controllers, providers (Riverpod)
application      → use-cases, orchestration, no framework deps
domain           → entities, value objects, contracts (framework-light)
data/adapters    → plugin impls, storage, network
plugin-facing    → contratos públicos que los plugins implementan
```

Dirección de dependencias permitida: presentation → application → domain ← adapters

## Reglas plugin-first

- Los plugins son ciudadanos de primera clase desde el día 1.
- Source plugins y resolver plugins son independientes entre sí.
- El player consume outputs ya resueltos; no invoca resolvers directamente.
- Los contratos de plugins definen el boundary; las implementaciones son intercambiables.

## Output esperado de una revisión arquitectónica

```md
Architecture Review
- Packages touched:
- Boundary crossed: yes | no
- Coupling risk:
- Contract impacts:
- Recommended minimal next step:
- What is intentionally left out:
```
