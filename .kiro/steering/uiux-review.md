---
inclusion: always
---

# UI/UX Review (Kumoriya)

Audita interfaces existentes de Kumoriya y propone mejoras UI/UX concretas e implementables dentro de las restricciones actuales de Flutter y Material 3.

## Cuándo activar este skill

Úsalo cuando:
- Revises pantallas existentes (Home, Search, Anime Detail, Episode List, Server Links, Resolve Result)
- Diagnostiques jerarquía visual, claridad de interacción, estados loading/empty/error/retry/unavailable
- Evalúes consistencia de design system y navegación
- Propongas mejoras UI incrementales y revisables

No usar para: implementación de business logic, trabajo de plugins/resolver/player, o refactors de arquitectura.

## Restricciones absolutas

1. Scope estrictamente en UI, layout, interacción y claridad visual.
2. No implementar features, reglas de negocio, source plugins, resolver plugins, playback ni cambios de arquitectura.
3. No reescribir flujos grandes cuando mejoras a nivel de pantalla resuelven el problema.
4. Preferir cambios incrementales y revisables.

## Flujo de auditoría

1. Definir target de auditoría y objetivo del usuario para la pantalla.
2. Inspeccionar estructura actual, spacing, tipografía, affordances de interacción y manejo de estados.
3. Identificar problemas UX concretos y explicar por qué cada problema aumenta confusión, fricción o riesgo de fallo.
4. Proponer cambios UI realistas vinculados a cada problema.
5. Priorizar cambios por impacto y esfuerzo de implementación.

## Reglas de contexto Kumoriya

- Tratar metadatos de AniList como contexto canónico para labels y jerarquía de información.
- Diseñar para incertidumbre plugin-first: source unavailable, no match, no links, resolver failure son estados normales y deben ser explícitos.
- Soportar ergonomía de interacción Android-first mientras se mantiene usable en Windows.
- Respetar i18n para diferencias de longitud de texto en inglés y español.
- Mantener propuestas compatibles con entrega por vertical slice.

## Checks requeridos por pantalla

- Jerarquía visual: ¿es la acción primaria visualmente dominante?
- Carga cognitiva: ¿se reducen elecciones simultáneas y ruido UI no esencial?
- Ritmo de spacing: ¿se usan tokens de spacing del design system con agrupación de secciones consistente?
- Affordances: ¿las acciones parecen tapeables y la intención es explícita?
- Claridad de navegación: ¿el usuario siempre sabe cuál es el siguiente paso?
- Calidad de estados: loading, empty, error, retry y unavailable.
- Consistencia con componentes y escala tipográfica existentes de Kumoriya.

## Estándares de calidad de estados

- Loading: mostrar intención de progreso y preservar estructura de página cuando sea posible.
- Empty: explicar por qué faltan datos y qué acción puede recuperarlos.
- Error: nombrar la fuente del fallo en lenguaje de usuario y ofrecer siguiente acción.
- Retry: proveer acción de retry explícita con label claro.
- Unavailable: indicar qué no está disponible ahora y qué alternativas existen.

## Reglas de UX defensiva

- Reemplazar acciones ambiguas como "Continue" genérico con labels específicos del outcome.
- Mostrar feedback post-acción para operaciones que cambian el contexto del usuario.
- Evitar dead ends donde no existe una siguiente acción clara.
- Preferir claridad de no-resultado sobre UI especulativa o engañosa.

## Checklist rápida de auditoría

### A nivel de pantalla
- [ ] ¿Es la acción primaria visualmente dominante?
- [ ] ¿El orden de información está alineado con el flujo de decisión del usuario?
- [ ] ¿El spacing de secciones es consistente e intencional?
- [ ] ¿Los labels son explícitos sobre los outcomes?
- [ ] ¿Hay un siguiente paso claro en cada rama?

### A nivel de estado
- [ ] Loading: ¿es el progreso visible y contextual?
- [ ] Empty: ¿se explica la ausencia con una acción de recuperación?
- [ ] Error: ¿se comunica la causa sin filtrar ruido técnico?
- [ ] Retry: ¿es el retry visible y seguro de repetir?
- [ ] Unavailable: ¿se ofrece fallback o ruta alternativa?

### Consistencia
- [ ] Niveles tipográficos siguen intención Material 3 y tokens del proyecto.
- [ ] Buttons, cards, chips y list items se comportan consistentemente entre pantallas.
- [ ] Flujos similares usan patrones de interacción similares.
- [ ] Copy EN/ES permanece conciso y claro en ambos idiomas.

### Casos de fallo Kumoriya
- [ ] Estado source unavailable es explícito y no bloqueante.
- [ ] Estado no match evita falsa confianza.
- [ ] Estado no server links previene confusión del usuario sobre siguiente acción.
- [ ] Estado resolver error ofrece retry y messaging de fallback.

## Contrato de output

Retornar siempre la auditoría en esta estructura exacta:

1. Screen diagnosis
2. Problems detected
3. UX impact
4. Concrete improvement proposals
5. Suggested UI-level changes

Mantener propuestas accionables para implementación Flutter. Referenciar archivos y widgets exactos cuando estén disponibles. Declarar suposiciones explícitamente cuando el contexto de pantalla esté incompleto.
