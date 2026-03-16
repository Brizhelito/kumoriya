---
inclusion: always
---

# Flutter Vertical Slice (Kumoriya)

Ejecuta exactamente un slice solicitado. Mantén los cambios pequeños, testeables y seguros para la arquitectura.

## Cuándo activar este skill

Úsalo cuando:
- Implementes un feature slice específico, bugfix slice, o paso incremental de producto
- Necesites mapear paquetes/capas afectados antes de codificar
- Debas ejecutar validación real (format/analyze/tests/build) y reportar milestones

## Restricciones absolutas

1. Leer y respetar los non-negotiables del proyecto antes de planificar código.
2. Implementar solo el slice explícitamente solicitado.
3. Rechazar expansión implícita. Si una dependencia necesaria está fuera de scope, agregar un seam/TODO mínimo en lugar de ampliar el trabajo.
4. Respetar límites modulares: UI no debe depender de implementaciones concretas de plugins; los contratos viven en paquetes plugin-facing.
5. Preferir comportamiento conservador sobre suposiciones inseguras.

## Bloque de scope (publicar antes de codificar)

```md
Slice Scope
- Goal:
- In scope:
- Out of scope:
- Done when:
```

Si el requerimiento es ambiguo, elegir la interpretación más estrecha y segura.

## Mapeo de paquetes y capas

Identificar módulos afectados antes de editar.

1. Localizar paquete(s) afectado(s) en el monorepo.
2. Mapear capas impactadas solo donde sea necesario:
   - presentation (widgets/controllers/providers)
   - application (use-cases/orchestration)
   - domain (entities/value objects/contracts)
   - data/plugin/storage adapters
3. Mantener dirección de dependencias limpia; no filtrar concerns de infra al dominio.

```md
Affected Areas
- package:
- layer(s):
- why touched:
```

## Plan de implementación incremental

Usar la secuencia más pequeña que entregue comportamiento funcional.

1. Crear plan corto (3-6 pasos máximo).
2. Ordenar por utilidad vertical (domain/app/presentation solo donde se necesite).
3. Preferir commits aditivos y revisables sobre diffs grandes mezclados.
4. Para cada paso, indicar artefacto esperado (código/test/wiring).

```md
Execution Plan
1. ...
2. ...
3. ...
```

## Disciplina de targeting de archivos

Antes de editar, listar archivos probables a tocar. Mantener lista ajustada.

```md
Probable Files
- path/to/file_a.dart (reason)
- path/to/file_b.dart (reason)
```

Si se requieren archivos nuevos, ubicarlos en el paquete/capa correcto y mantener naming consistente con convenciones existentes.

## Validación obligatoria

Ejecutar checks reales; nunca declarar estabilidad sin evidencia de ejecución.

```md
Validation Checklist
- [ ] dart format <affected paths>
- [ ] dart analyze (affected package or repo rule)
- [ ] relevant tests (unit/widget/integration for slice)
- [ ] run/build check when slice affects runtime wiring, startup, navigation, platform, or generated code
```

Reglas:
- Si un comando no puede ejecutarse, decir exactamente por qué.
- Reportar fallos y riesgo residual explícitamente.
- No marcar items del checklist como completos sin ejecución del comando.

## Versionado por milestones

```md
Versioning Milestones
1. <type(scope): message> - <intent>
2. <type(scope): message> - <intent>
```

Usar conventional commits. Mantener edits no relacionadas fuera del milestone.

## Plantilla de reporte final

```md
Slice Delivery Report
- Scope recap:
- Implemented:
- Files changed:
- Validation run:
  - command: <cmd>
  - result: <pass/fail>
- Residual risk:
- Suggested next slice:
```

No incluir roadmap futuro especulativo salvo que el usuario lo pida.
