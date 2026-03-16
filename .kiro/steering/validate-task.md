---
inclusion: always
---

# Validate Task (Kumoriya)

Ejecuta un pase de validación estricto antes de declarar una tarea de Kumoriya como completada.

## Cuándo activar este skill

Úsalo cuando:
- Estés cerrando cualquier tarea de implementación en Kumoriya
- Necesites confirmar que format, analyze y tests pasaron realmente
- Quieras reportar riesgo residual honestamente antes de hacer commit

## Checklist de cierre obligatorio

- [ ] `dart format` ejecutado en paths afectados
- [ ] `dart analyze` limpio en paquete(s) afectado(s)
- [ ] Tests relevantes ejecutados (no omitidos sin declararlo)
- [ ] El flujo objetivo fue realmente ejercido (no solo compilado)
- [ ] Riesgos residuales declarados honestamente
- [ ] Scope creep evitado (no se tocó lo que no debía tocarse)
- [ ] Commits claros y descriptivos (conventional commit style)

## Reglas de no-completitud

No declarar una tarea como estable si:
- La app no compila.
- El flujo objetivo no fue realmente ejercido.
- Tests fueron omitidos sin declararlo explícitamente.

## Formato de output obligatorio

```md
Task Validation Report
1. What changed:
2. What was validated:
   - format: <command + result>
   - analyze: <command + result>
   - tests: <command + result>
   - flow exercised: yes | no | partial (explain)
3. What was NOT validated (and why):
4. Residual risk:
5. Recommended next step:
```

No omitir la sección "What was NOT validated". Si todo fue validado, declararlo explícitamente.
