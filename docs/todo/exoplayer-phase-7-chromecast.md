# TODO — ExoPlayer Fase 7: Chromecast

- **Estado:** Pospuesto (Fases 0-5 entregadas; bloqueado hasta resolver
  estrategia de sources compatibles).
- **Área:** `packages/kumoriya_exoplayer` (Kotlin) + UI en
  `apps/kumoriya_app/lib/src/features/player/presentation/`.
- **Dependencias nuevas probables:**
  - `androidx.media3:media3-cast:<bom>` (ya disponible vía Media3 BOM).
  - Google Cast SDK (`com.google.android.gms:play-services-cast-framework`).
  - Registrar Cast receiver id en Google Cast SDK Developer Console.
- **Riesgo principal:** sources que requieren headers custom o el proxy
  local **no castean** (la TV no tiene acceso a ese canal). Detectar y
  deshabilitar botón con explicación.

## Alcance (según `docs/kumoriya-exoplayer-plan.md:187-195`)

1. **Integración `media3-cast`**: `CastPlayer` swappeable con el
   `ExoPlayer` local mediante el pattern recomendado de Media3
   (`CastContext` + listener).
2. **UI**: `MediaRouteButton` en el player con animación de conectando /
   conectado / desconectado.
3. **Preservar estado al swap**: posición, audio track seleccionada,
   subtitle track seleccionada, speed. Al desconectar Cast, volver al
   player local con mismo estado.
4. **Compatibilidad por source**:
   - Sources públicos sin auth custom (Zilla, Streamwish simple,
     public mp4) → casteables.
   - Sources con headers custom / proxy local (AnimeNexus, FileMoon
     con referer firmado, etc.) → botón deshabilitado con tooltip
     `"Este servidor no soporta Chromecast"`.
   - Detección: el resolver expone un flag `castable: bool` o se
     infiere de si el `ResolvedStream` trae headers distintos de los
     estándar de navegación.

## Gate de aceptación

- Castear Zilla o Streamwish desde el móvil a un Chromecast real.
- Control play/pause/seek desde el móvil con el video en TV.
- Desconexión limpia al apagar Chromecast o cerrar app (sin sesión
  zombie).
- AnimeNexus muestra botón Cast en gris con tooltip explicativo.
- Subtítulos externos se castean si son URL pública; si son bytes
  inline, degradar a "no subs en Cast" con aviso.

## Riesgos y notas

- **Sesiones zombie**: Cast SDK a veces deja sesiones colgadas tras
  crashes; implementar cleanup al `onResume` del player.
- **Receiver custom vs default**: default receiver de Google cubre MP4,
  HLS, DASH. Si aparece un codec raro (AV1 nativo en TVs que lo soportan),
  revisar si conviene receiver custom (mucho más trabajo — documentar
  alcance).
- **Android TV devices**: el Cast SDK funciona; Fire TV con Cast no es
  oficial pero suele andar. No se promete soporte.
- **Watch Party + Cast**: incompatibles en primera versión (Cast rompe el
  model P2P; el party line queda solo para el "host" que castea).
  Documentar limitación.

## LOC estimado

~700 (plan original).

## Referencias

- Plan maestro: `docs/kumoriya-exoplayer-plan.md` (Fase 7, líneas 187-195).
- Player actual: `packages/kumoriya_exoplayer/android/src/main/kotlin/`.
- Resolver contract donde añadir `castable`:
  `packages/kumoriya_resolver_common/lib/src/contracts/`.
