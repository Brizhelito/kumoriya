# Anime Nexus Node Runtime

Runtime experimental paralelo para Anime Nexus sin Dart.

## Qué hace

- resuelve un `watchUrl` de Anime Nexus
- hace bootstrap HTTP de sesión/fingerprint
- abre el WebSocket de tokens con Node + `ws`
- expone manifests/segmentos por un proxy HLS local

## Uso

```bash
cd tools/anime-nexus-runtime-node
npm install
npm start
```

Resolver un episodio:

```bash
curl -X POST http://127.0.0.1:43127/resolve \
  -H "content-type: application/json" \
  -d '{"watchUrl":"https://anime.nexus/watch/019cb301-d4de-7052-b26a-0f9625a09a38/episode-1-0704963ad12400b916bf"}'
```

Smoke:

```bash
cd tools/anime-nexus-runtime-node
npm install
npm run smoke
```

Test suite:

```bash
cd tools/anime-nexus-runtime-node
npm test
```

Live matrix:

```bash
cd tools/anime-nexus-runtime-node
npm run test:live
```

## Alcance actual

Esto es un runtime experimental para validar si Node + `ws` puede sostener el flujo de Anime Nexus fuera del resolver Dart. No sustituye todavía el contrato oficial de plugins de Kumoriya.

La suite actual cubre:

- validacion de entrada en `/resolve`
- expiracion y limpieza de sesiones
- timeouts HTTP/CDN
- fallback de host para manifests/media
- cierre seguro del WebSocket incluso en `CONNECTING`
- seeks fuera de orden y concurrencia basica con upstream lento simulado

Limite honesto actual:

- en validacion real contra Anime Nexus, `resolve`, `master`, `variant` e `init` responden `200` en dos episodios verificados
- la primera bajada de `segment` real sigue pudiendo entrar en timeout; ese endurecimiento live del tramo largo queda abierto
