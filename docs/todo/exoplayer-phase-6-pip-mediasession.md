# TODO — ExoPlayer Fase 6: PiP + MediaSession + Watch Party Overlay (M6)

- **Estado:** Pospuesto (Fases 0-5 del plan `kumoriya-exoplayer-plan.md`
  entregadas; prioridad tras estabilizar downloads + sync).
- **Área:** `packages/kumoriya_exoplayer` (Kotlin) + integración UI en
  `apps/kumoriya_app/lib/src/features/player/` y
  `apps/kumoriya_app/lib/src/features/watch_party/`.
- **Dependencias nuevas probables:** ninguna (`androidx.media3-session` ya
  disponible vía Media3 BOM del plugin).
- **Riesgo principal:** el overlay en PiP es limitado por Android — no se
  pueden poner Flutter widgets encima del Surface cuando la Activity está
  en modo PiP. Hay que dibujar con primitivas nativas.

## Alcance (según `docs/kumoriya-exoplayer-plan.md:178-185`)

1. **Picture-in-Picture** con `PictureInPictureParams`:
   - Aspect ratio del video.
   - Acciones play / pause / skip ±10s en la ventana flotante.
   - Trigger desde botón en player UI + auto-PiP al hacer home (opt-in).
2. **MediaSessionCompat**:
   - Lockscreen con miniatura, título, controles.
   - Bluetooth headset controls (play/pause/next/prev).
   - Android Auto (smoke test, no se promete soporte completo).
3. **Watch Party emoji overlay en PiP**:
   - Render nativo con `SurfaceView` + `Canvas` o `RemoteViews` para
     mostrar los emojis del `WatchPartyRealtime` stream por encima del
     video cuando el player está en PiP.
   - Fuera de PiP el overlay sigue siendo Flutter (como hoy).

## Gate de aceptación

- PiP funciona al hacer home con video en play.
- Controles play/pause/skip desde la ventana PiP.
- BT headset controla reproducción con app backgrounded.
- Lockscreen muestra miniatura + título + controles.
- En watch party con PiP activo, los emojis de los demás aparecen encima
  del video chico.

## Riesgos y notas

- **Flutter + PiP**: el framework Flutter no pinta en PiP correctamente;
  hay que usar `FlutterActivity` con manifest `supportsPictureInPicture` y
  la UI de overlay hay que hacerla puramente nativa.
- **Emojis en overlay nativo**: si el código actual de emojis en Flutter
  es complejo, considerar exponer solo los últimos 3-5 emojis y renderizar
  con `TextView` animado o `Canvas.drawText`.
- **MediaSession + multiple players**: si hay dos instancias (poco
  probable pero posible con PiP + detail), solo una puede tener la
  sesión activa. Gestionar ownership con un `MediaSessionService`.

## LOC estimado

~800 (plan original).

## Referencias

- Plan maestro: `docs/kumoriya-exoplayer-plan.md` (Fase 6, líneas 178-185).
- Player actual Android: `packages/kumoriya_exoplayer/android/src/main/kotlin/`.
- Watch Party realtime stream:
  `apps/kumoriya_app/lib/src/features/watch_party/application/party_sync_engine.dart`.
