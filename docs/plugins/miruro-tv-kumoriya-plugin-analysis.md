# Análisis Técnico: miruro.tv
## Guía para Desarrollo de Plugins Kumoriya

> **Fecha de análisis:** Junio 2026  
> **Sitio analizado:** https://www.miruro.tv  
> **Repositorio oficial:** https://github.com/Miruro-no-kuon/Miruro

---

## 1. INFORMACIÓN GENERAL DEL SITIO

### URL Base
```
https://www.miruro.tv
```
Dominios oficiales:
- `miruro.com` (hub principal)
- `miruro.tv` ← **el analizado**
- `miruro.online`

### Tipo de Sitio
| Característica | Valor |
|---|---|
| **Framework frontend** | React 18 + TypeScript + Vite |
| **Renderizado** | SPA (Single Page Application) — **requiere JavaScript** |
| **Despliegue** | Vercel + Cloudflare |
| **¿API pública?** | ❌ No — backend privado con cifrado |
| **¿Requiere autenticación?** | ❌ No (opcional: login AniList para sync) |
| **¿Anti-bot?** | ✅ Cloudflare + cifrado AES-256-GCM en todas las peticiones |
| **¿Contenido dinámico JS?** | ✅ **100% dinámico** — el HTML base está vacío |

### ⚠️ ADVERTENCIA CRÍTICA: El HTML estático es inútil
El scraping HTML directo **no funciona** en Miruro. La respuesta HTML sin JS es:
```html
<!DOCTYPE html>
<html>
  <head>...</head>
  <body>
    <div id="root"></div>  <!-- VACÍO — React lo llena dinámicamente -->
    <noscript>Miruro requires JavaScript.</noscript>
  </body>
</html>
```
Todo el contenido es renderizado por React en el cliente. **Debes usar la API subyacente**, no scraping HTML.

---

## 2. ARQUITECTURA DEL BACKEND Y CIFRADO (El "Secure Pipe")

Miruro.tv usa un túnel para todas sus llamadas API internas:

```
Frontend → GET /api/secure/pipe?e={payload_base64url} → Backend Node.js
```

### 2.1. Formato de la Petición (Request)
A diferencia de lo que se pensaba inicialmente, **las peticiones no están cifradas con AES**. Son simplemente objetos JSON codificados en Base64URL.

Ejemplo de payload JSON antes de codificar:
```json
{
  "path": "episodes",
  "method": "GET",
  "query": { "anilistId": "21" },
  "body": null,
  "version": "0.2.0"
}
```
Este JSON se convierte a Base64URL y se envía en el parámetro `?e=`.

### 2.2. Formato de la Respuesta (Response) y Ofuscación
El servidor responde con un header `x-obfuscated: 2` y un body en texto plano (Base64URL). Para leer el JSON real, se debe aplicar el siguiente algoritmo de descifrado:

1. **Obtener la clave de ofuscación:** Miruro inyecta una clave dinámica en el frontend. Se puede obtener haciendo un `GET https://www.miruro.tv/env2.js`.
   - El archivo contiene algo como: `window.env=JSON.parse("{\"VITE_PIPE_OBF_KEY\":\"71951034f8fbcf53d89db52ceb3dc22c\",...}");`
   - Extraer el valor de `VITE_PIPE_OBF_KEY`.
2. **Decodificar Base64URL:** Convertir el body de la respuesta de Base64URL a un array de bytes (`Uint8Array`).
3. **Aplicar XOR:** Convertir la clave hexadecimal a bytes. Iterar sobre los bytes de la respuesta y aplicar una operación XOR (`^`) con los bytes de la clave (repitiendo la clave cíclicamente).
4. **Descomprimir GZIP:** El resultado del XOR es un buffer comprimido en GZIP. Descomprimirlo (ej. `zlib.gunzipSync` o equivalente en Dart).
5. **Parsear JSON:** El resultado descomprimido es el JSON final en texto plano.

### 2.3. Estrategia Recomendada para el Plugin
Para evitar que el plugin se rompa si la clave rota:
1. Al inicializar, hacer un `GET /env2.js` y guardar la clave en memoria.
2. Usar esta clave para descifrar todas las respuestas de `/api/secure/pipe`.
3. Si una descompresión GZIP falla, asumir que la clave rotó, volver a hacer fetch a `/env2.js` y reintentar.

---

## 3. FUENTES DE DATOS REALES

Aunque podemos usar el "Secure Pipe" de Miruro directamente gracias al algoritmo descubierto, es útil conocer la arquitectura subyacente:

```
miruro.tv
├── Metadatos de anime ──────────────→ AniList GraphQL API
│                                       https://graphql.anilist.co
│
├── Lista de episodios ──────────────→ Múltiples proveedores vía Consumet
│   ├── Provider "kiwi"  ────────────→ AnimePahe (animepahe.com)
│   ├── Provider "zoro"  ────────────→ HiAnime (hianime.to)
│   ├── Provider "arc"   ────────────→ AnimePahe variante
│   └── Provider "jet"   ────────────→ Desconocido
│
└── Streams de video ────────────────→ Kwik.si (para pahe) / CDN directo (para zoro)
    └── Formato final: HLS (M3U8)
```

---

## 3. SISTEMA DE IDENTIFICADORES

### ⭐ AniList IDs — El identificador universal de Miruro

**Todos** los IDs de anime en Miruro son **AniList IDs**. Este es el núcleo del sistema.

```
URL pattern:  /info/{anilist_id}/{slug}
URL pattern:  /watch/{anilist_id}/{slug}
```

Ejemplos:
| Anime | AniList ID | URL en Miruro |
|---|---|---|
| ONE PIECE | `21` | `https://www.miruro.tv/info/21/one-piece` |
| Naruto | `20` | `https://www.miruro.tv/info/20/naruto` |
| Naruto: Shippuden | `1735` | `https://www.miruro.tv/info/1735/naruto-shippuden` |
| Attack on Titan | `16498` | `https://www.miruro.tv/info/16498/shingeki-no-kyojin` |
| Re:Zero S4 | `189046` | `https://www.miruro.tv/info/189046/rezero-kara-hajimeru-isekai-seikatsu-4th-season` |

El `slug` (parte de texto en la URL) es **opcional** para la navegación; el ID numérico es lo que importa.

---

## 4. API RECOMENDADA PARA EL PLUGIN SOURCE

Dado que Miruro usa AniList como fuente de metadatos, el **Source Plugin de Kumoriya** debe llamar directamente a la **AniList GraphQL API**. Es pública, gratuita y sin autenticación para consultas básicas.

### Endpoint Base
```
POST https://graphql.anilist.co
Content-Type: application/json
```

---

## 5. BÚSQUEDA DE ANIME — `search()`

### Request GraphQL
```graphql
query SearchAnime($query: String, $page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    pageInfo {
      total
      currentPage
      lastPage
      hasNextPage
      perPage
    }
    media(search: $query, type: ANIME, isAdult: false) {
      id
      title {
        romaji
        english
        native
      }
      coverImage {
        large
        extraLarge
        color
      }
      bannerImage
      format
      status
      episodes
      duration
      season
      seasonYear
      averageScore
      popularity
      genres
      studios(isMain: true) {
        nodes {
          name
        }
      }
    }
  }
}
```

Variables:
```json
{
  "query": "naruto",
  "page": 1,
  "perPage": 20
}
```

URL de ejemplo equivalente en Miruro (para verificar resultados):
```
https://www.miruro.tv/search?q=naruto
```

### Respuesta JSON (ejemplo real)
```json
{
  "data": {
    "Page": {
      "pageInfo": {
        "total": 42,
        "currentPage": 1,
        "lastPage": 3,
        "hasNextPage": true,
        "perPage": 20
      },
      "media": [
        {
          "id": 20,
          "title": {
            "romaji": "Naruto",
            "english": "Naruto",
            "native": "ナルト"
          },
          "coverImage": {
            "large": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/medium/bx20-YetEDmGTjnCF.jpg",
            "extraLarge": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx20-YetEDmGTjnCF.jpg",
            "color": "#e48850"
          },
          "bannerImage": "https://s4.anilist.co/file/anilistcdn/media/anime/banner/20.jpg",
          "format": "TV",
          "status": "FINISHED",
          "episodes": 220,
          "duration": 23,
          "season": "FALL",
          "seasonYear": 2002,
          "averageScore": 79,
          "popularity": 436942,
          "genres": ["Action", "Adventure", "Fantasy"],
          "studios": {
            "nodes": [{ "name": "Pierrot" }]
          }
        }
      ]
    }
  }
}
```

### Mapping para Kumoriya `search()`
```typescript
// Cada resultado de búsqueda → AnimeSearchResult
{
  id: media.id.toString(),          // "20"
  title: media.title.english        // "Naruto"
       ?? media.title.romaji,
  image: media.coverImage.large,    // URL del poster
  year: media.seasonYear,           // 2002
  format: media.format,             // "TV" | "MOVIE" | "OVA" | "ONA" | "SPECIAL"
  totalEpisodes: media.episodes,    // 220
}
```

---

## 6. DETALLE DE ANIME — `getAnimeDetail()`

### Request GraphQL
```graphql
query GetAnimeDetail($id: Int) {
  Media(id: $id, type: ANIME) {
    id
    idMal
    title {
      romaji
      english
      native
      userPreferred
    }
    description(asHtml: false)
    coverImage {
      large
      extraLarge
      color
    }
    bannerImage
    format
    status
    episodes
    duration
    season
    seasonYear
    averageScore
    meanScore
    popularity
    favourites
    genres
    synonyms
    hashtag
    source
    countryOfOrigin
    isAdult
    studios(isMain: true) {
      nodes {
        name
        siteUrl
      }
    }
    startDate { year month day }
    endDate { year month day }
    nextAiringEpisode {
      airingAt
      episode
      timeUntilAiring
    }
    trailer {
      id
      site
    }
    tags {
      name
      rank
      isMediaSpoiler
    }
    relations {
      edges {
        relationType(version: 2)
        node {
          id
          title { romaji english }
          format
          coverImage { large }
        }
      }
    }
    recommendations(sort: RATING_DESC, perPage: 10) {
      nodes {
        mediaRecommendation {
          id
          title { romaji english }
          coverImage { large }
          averageScore
        }
      }
    }
  }
}
```

Variables:
```json
{ "id": 21 }
```

URL equivalente en Miruro:
```
https://www.miruro.tv/info/21/one-piece
```

### Respuesta JSON (estructura real — One Piece)
```json
{
  "data": {
    "Media": {
      "id": 21,
      "idMal": 21,
      "title": {
        "romaji": "ONE PIECE",
        "english": "ONE PIECE",
        "native": "ONE PIECE"
      },
      "description": "Gold Roger was known as the Pirate King...",
      "coverImage": {
        "large": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/medium/bx21-2GKBjWsEqAOg.jpg",
        "extraLarge": "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21-2GKBjWsEqAOg.jpg",
        "color": "#e4a15d"
      },
      "bannerImage": "https://s4.anilist.co/file/anilistcdn/media/anime/banner/21.jpg",
      "format": "TV",
      "status": "RELEASING",
      "episodes": null,
      "duration": 24,
      "season": "FALL",
      "seasonYear": 1999,
      "averageScore": 87,
      "genres": ["Action", "Adventure", "Comedy", "Drama", "Fantasy"],
      "synonyms": [],
      "source": "MANGA",
      "countryOfOrigin": "JP",
      "studios": {
        "nodes": [{ "name": "Toei Animation" }]
      },
      "startDate": { "year": 1999, "month": 10, "day": 20 },
      "endDate": { "year": null, "month": null, "day": null },
      "nextAiringEpisode": {
        "airingAt": 1750200000,
        "episode": 1127,
        "timeUntilAiring": 43200
      }
    }
  }
}
```

### Mapping para Kumoriya `getAnimeDetail()`
```typescript
{
  id: media.id.toString(),
  title: media.title.english ?? media.title.romaji,
  titleAlternatives: [
    media.title.romaji,
    media.title.native,
    ...media.synonyms
  ].filter(Boolean),
  synopsis: media.description,       // texto plano (sin HTML)
  image: media.coverImage.extraLarge,
  banner: media.bannerImage,
  year: media.seasonYear,
  format: media.format,              // "TV" | "MOVIE" | "OVA" | etc.
  status: media.status,              // "RELEASING" | "FINISHED" | etc.
  totalEpisodes: media.episodes,     // null si está en emisión sin fecha fin
  season: media.season,              // "FALL" | "SPRING" | etc.
  genres: media.genres,
  score: media.averageScore,
  studio: media.studios.nodes[0]?.name,
}
```

---

## 7. LISTADO DE EPISODIOS — `getEpisodes()`

### Estrategia: API Consumet / Miruro-API

Los episodios se obtienen de la **API Consumet** (o equivalente) usando el AniList ID. Miruro usa su propio backend privado, pero la comunidad ha reverse-engineered endpoints equivalentes.

#### Opción A: Consumet API (original, a veces inestable)
```
GET https://api.consumet.org/meta/anilist/episodes/{anilist_id}
```

#### Opción B: Miruro-API (reverse-engineered, más completo)
```
GET https://{tu-instancia-miruro-api}/episodes/{anilist_id}
```

Ejemplo:
```
GET /episodes/178005
```

### Respuesta JSON Completa
```json
{
  "mappings": {
    "anilistId": 178005,
    "malId": 56885,
    "kitsuId": 47905,
    "anidbId": 17958
  },
  "providers": {
    "kiwi": {
      "episodes": {
        "sub": [
          {
            "id": "watch/kiwi/178005/sub/animepahe-1",
            "number": 1,
            "title": "A World Without Neon Genesis",
            "image": "https://serveproxy.com/url?url=https://i.animepahe.ru/snapshots/...",
            "airDate": "2026-01-04",
            "duration": 1420,
            "description": "Episode description here...",
            "filler": false
          },
          {
            "id": "watch/kiwi/178005/sub/animepahe-2",
            "number": 2,
            "title": "Title of Episode 2",
            "image": "https://serveproxy.com/url?url=...",
            "airDate": "2026-01-11",
            "duration": 1420,
            "description": "...",
            "filler": false
          }
        ],
        "dub": [
          {
            "id": "watch/kiwi/178005/dub/animepahe-1",
            "number": 1,
            "title": "A World Without Neon Genesis",
            "image": "...",
            "airDate": "2026-01-04",
            "duration": 1420,
            "description": "...",
            "filler": false
          }
        ]
      }
    },
    "arc": {
      "episodes": {
        "sub": [ /* misma estructura */ ],
        "dub": []
      }
    },
    "zoro": {
      "episodes": {
        "sub": [
          {
            "id": "watch/zoro/178005/sub/hianime-ep1",
            "number": 1,
            "title": "Episode 1",
            "image": null,
            "airDate": "2026-01-04",
            "duration": null,
            "description": null,
            "filler": false
          }
        ],
        "dub": []
      }
    }
  }
}
```

### Formato del ID de Episodio
```
watch/{provider}/{anilist_id}/{category}/{source_id}

Componentes:
├── provider:    kiwi | arc | zoro | jet
├── anilist_id:  ID de AniList del anime
├── category:    sub | dub
└── source_id:   ID interno del proveedor (animepahe-1, hianime-ep1, etc.)
```

### Mapping para Kumoriya `getEpisodes()`
```typescript
// Seleccionar proveedor preferido (kiwi primero, luego zoro como fallback)
const providerOrder = ['kiwi', 'zoro', 'arc', 'jet'];

// Para cada episodio del proveedor elegido
episodes.map(ep => ({
  id: ep.id,                   // "watch/kiwi/178005/sub/animepahe-1"
  number: ep.number,           // 1, 2, 2.5 (para especiales), etc.
  title: ep.title,             // "Episode Title" o null
  thumbnail: ep.image,         // URL o null
  airDate: ep.airDate,         // "2026-01-04"
  isFiller: ep.filler,         // boolean
}))
```

---

## 8. PÁGINA DE EPISODIO Y SERVIDORES — `getEpisodeServerLinks()`

### Obtener el Stream de Video

Para obtener los servidores de video, se debe hacer una petición al "Secure Pipe" de Miruro con el `path` configurado como `sources`.

**Payload JSON a codificar en Base64URL:**
```json
{
  "path": "sources",
  "method": "GET",
  "query": {
    "episodeId": "YW5pbWVwYWhlOjQ6MzY2MDA6Mzk", // ID del episodio en base64
    "provider": "kiwi", // El proveedor seleccionado
    "category": "sub", // "sub" o "dub"
    "anilistId": 21 // Opcional, pero recomendado
  },
  "body": null,
  "version": "0.2.0"
}
```

### Respuesta JSON del Stream (Descifrada con XOR+GZIP)

Miruro actúa como un "mega-resolver". Su backend resuelve los embeds de terceros y devuelve directamente los enlaces `.m3u8` o `.mp4` listos para reproducir, junto con los embeds originales como respaldo.

Ejemplo de respuesta para el proveedor `kiwi` (AnimePahe):
```json
{
  "streams": [
    {
      "url": "https://vault-05.uwucdn.top/stream/.../uwu.m3u8",
      "type": "hls",
      "quality": "1080p",
      "resolution": { "width": 1920, "height": 1080 },
      "codec": "h264",
      "audio": "sub",
      "isActive": true,
      "referer": "https://kwik.cx/"
    },
    {
      "url": "https://kwik.cx/e/InzZMv1U52OE",
      "type": "embed",
      "quality": "1080p",
      "referer": "https://kwik.cx/"
    }
  ]
}
```

### Mapping para Kumoriya `getEpisodeServerLinks()`

El plugin debe devolver **todas** las fuentes disponibles, permitiendo que el sistema de Kumoriya (o el usuario) seleccione la mejor opción.

```typescript
// Mapeo de los streams devueltos por Miruro
streams.map((stream, index) => {
  const isDirect = stream.type === 'hls' || stream.type === 'mp4';
  
  return {
    id: `${provider}-${stream.type}-${stream.quality || stream.server || index}`,
    name: `${providerDisplayName} ${stream.quality || stream.server || 'Auto'}`,
    url: stream.url,
    // Si es directo, Kumoriya lo reproduce nativamente. Si es embed, Kumoriya decide si usar un Resolver Plugin o un WebView.
    type: isDirect ? 'stream' : 'embed', 
    quality: stream.quality,   // "1080p", "720p", etc.
    language: category,        // "sub" | "dub"
    headers: stream.referer ? { 'Referer': stream.referer } : {}, // REQUERIDO para playback
  };
})
```

**Nota sobre Embeds:** Aunque Miruro devuelve embeds (ej. `kwik.cx`, `vibeplayer.site`), en el 90% de los casos también devuelve el stream directo (`hls`/`mp4`) en la misma respuesta. El plugin debe priorizar y exponer los streams directos, pero también incluir los embeds como plan de respaldo por si el stream directo falla o si Kumoriya cuenta con un resolver específico para ese embed.

---

## 9. ANÁLISIS DE HOSTINGS DE VIDEO

### ⚠️ Miruro NO usa hostings de video convencionales

A diferencia de sitios como GogoAnime o HiAnime que usan VOE, Filemoon, StreamTape, etc., **Miruro entrega los M3U8 directamente** desde los CDN de sus proveedores internos. No hay un paso de "resolver embed" como tal.

### Proveedor 1: kiwi → AnimePahe → Kwik.si CDN

| Atributo | Valor |
|---|---|
| **Proveedor fuente** | AnimePahe (animepahe.com) |
| **CDN de video** | Kwik.si / Akamai CDN |
| **Formato de stream** | HLS (M3U8) |
| **Subtítulos** | Hard-subbed (quemados en el video) |
| **Calidades disponibles** | 360p, 480p, 720p, 1080p |
| **Requiere Referer** | ✅ `Referer: https://kwik.si/` |

**Estructura de URL del stream:**
```
https://na-{server}.cdn.kwik.si/hls/{hash}/{quality}.m3u8
  o
https://eu-{server}.cdn.kwik.si/hls/{hash}/{quality}.m3u8
```

**Headers HTTP requeridos para playback:**
```http
Referer: https://kwik.si/
User-Agent: Mozilla/5.0 (...)
```

**Patrón del ID de episodio AnimePahe:**
```
animepahe-{numero_episodio}
```
Ejemplo: `animepahe-1`, `animepahe-2`, `animepahe-12`

---

### Proveedor 2: zoro → HiAnime (hianime.to)

| Atributo | Valor |
|---|---|
| **Proveedor fuente** | HiAnime (hianime.to / aniwatch.to) |
| **CDN de video** | RabbitStream / MegaCloud |
| **Formato de stream** | HLS (M3U8) |
| **Subtítulos** | Externos (VTT, SRT, ASS) — ✅ en array `subtitles` |
| **Calidades disponibles** | Auto / múltiples |
| **Requiere Referer** | ✅ `Referer: https://hianime.to/` |

**Subtítulos externos (formato VTT):**
```json
{
  "subtitles": [
    {
      "file": "https://s.megacdn.io/subtitles/en.vtt",
      "label": "English",
      "kind": "captions"
    },
    {
      "file": "https://s.megacdn.io/subtitles/es.vtt",
      "label": "Spanish",
      "kind": "captions"
    }
  ]
}
```

---

### Proveedor 3: arc → AnimePahe variante

Mismo comportamiento que `kiwi`, funciona como fallback:
- Streams M3U8 desde CDN similar
- Subtítulos hard-subbed
- Requiere `Referer: https://kwik.si/`

---

### Resumen de hostings (tabla completa)

| Provider | Fuente | Tipo stream | Formato | Subtítulos | Referer necesario |
|---|---|---|---|---|---|
| `kiwi` | AnimePahe/Kwik | HLS M3U8 | `.m3u8` | Hard-sub | `kwik.si` |
| `zoro` | HiAnime/MegaCloud | HLS M3U8 | `.m3u8` | VTT externo | `hianime.to` |
| `arc` | AnimePahe variante | HLS M3U8 | `.m3u8` | Hard-sub | `kwik.si` |
| `jet` | Desconocido | HLS M3U8 | `.m3u8` | Variable | Desconocido |

---

## 10. URLS DE PRUEBA FUNCIONALES

### Anime popular con muchos episodios
```
ONE PIECE (AniList ID: 21)
Info:  https://www.miruro.tv/info/21/one-piece
Watch: https://www.miruro.tv/watch/21/one-piece

Naruto (AniList ID: 20)
Info:  https://www.miruro.tv/info/20/naruto
```

### Anime con pocos episodios
```
Re:Zero S4 (AniList ID: 189046)
Info:  https://www.miruro.tv/info/189046/rezero-kara-hajimeru-isekai-seikatsu-4th-season

Dr. STONE Science Future Cour 3 (AniList ID: 199221)
Info:  https://www.miruro.tv/info/199221/dr-stone-science-future-cour-3
```

### Película
```
Attack on Titan: The Final Chapters (OVA/Special)
Buscar por: https://www.miruro.tv/search?format=MOVIE
```

### Anime con especiales
```
ONE PIECE (tiene múltiples side stories)
- ONE PIECE: Taose! Kaizoku Ganzack (AniList: 466)
- One Piece: Umi no Heso (AniList: 1094)
```

### Búsquedas de ejemplo funcionales
```
https://www.miruro.tv/search?q=naruto
https://www.miruro.tv/search?q=one+piece
https://www.miruro.tv/search?sort=POPULARITY_DESC
https://www.miruro.tv/search?format=MOVIE&type=ANIME
https://www.miruro.tv/search?season=SPRING&startDate_like=2024%25
```

---

## 11. QUERIES GRAPHQL ADICIONALES (AniList)

### Trending Anime
```graphql
query {
  Page(page: 1, perPage: 20) {
    media(type: ANIME, sort: TRENDING_DESC, isAdult: false) {
      id
      title { romaji english }
      coverImage { large }
      format
      status
      episodes
    }
  }
}
```

### Filtro Avanzado (equivale a `/search` con parámetros)
```graphql
query AdvancedSearch(
  $query: String
  $genre: [String]
  $format: MediaFormat
  $status: MediaStatus
  $season: MediaSeason
  $year: Int
  $sort: [MediaSort]
  $page: Int
  $perPage: Int
) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage total }
    media(
      search: $query
      genre_in: $genre
      format: $format
      status: $status
      season: $season
      seasonYear: $year
      sort: $sort
      type: ANIME
      isAdult: false
    ) {
      id
      title { romaji english }
      coverImage { large }
      format
      status
      episodes
      seasonYear
    }
  }
}
```

Variables de ordenamiento disponibles:
```
TRENDING_DESC | POPULARITY_DESC | SCORE_DESC | START_DATE_DESC | UPDATED_AT_DESC
```

---

## 12. CASOS ESPECIALES Y EDGE CASES

### Anime sin episodios (próximos)
- `media.episodes` será `null`
- `media.status` será `"NOT_YET_RELEASED"`
- La API de episodios devuelve `{ "providers": {} }` (objeto vacío)

### Episodios especiales (numeración decimal)
AnimePahe maneja episodios especiales con numeración decimal:
```json
{ "id": "watch/kiwi/20/sub/animepahe-2-5", "number": 2.5, "title": "Special" }
```
Los episodios 0 son recaps o prologos:
```json
{ "id": "watch/kiwi/20/sub/animepahe-0", "number": 0, "title": "Prologue" }
```

### Anime solo Sub vs Solo Dub
- Si `dub` está vacío `[]`, solo hay versión subtitulada
- El proveedor `kiwi` tiene mejor cobertura de dub que `zoro`

### URLs de imágenes (AniList CDN)
```
https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx{id}-{hash}.jpg
https://s4.anilist.co/file/anilistcdn/media/anime/banner/{id}.jpg
https://img.anili.st/media/{id}  ← versión simplificada que usa Miruro
```

### Protección anti-hotlinking de Kwik.si
Los streams de Kwik requieren el header `Referer: https://kwik.si/` — sin este header el servidor devuelve 403. El `User-Agent` también debe ser un browser estándar.

### Series con muchas temporadas
Cada temporada es un AniList ID separado. Por ejemplo:
- Naruto = `20` (220 eps)
- Naruto Shippuden = `1735` (500 eps)
- Son entidades completamente independientes en AniList y Miruro

---

## 13. IMPLEMENTACIÓN DEL SOURCE PLUGIN

```typescript
// miruro-source-plugin.ts (para Kumoriya)

const ANILIST_API = 'https://graphql.anilist.co';
const EPISODES_API = 'https://{tu-instancia}/episodes';  // Miruro-API o Consumet

export const MiruroSourcePlugin = {
  id: 'miruro',
  name: 'Miruro',
  version: '1.0.0',

  // ─── BÚSQUEDA ────────────────────────────────────────────
  async search(query: string, page = 1): Promise<SearchResult[]> {
    const gql = `
      query($q: String, $page: Int) {
        Page(page: $page, perPage: 20) {
          pageInfo { hasNextPage total }
          media(search: $q, type: ANIME, isAdult: false, sort: SEARCH_MATCH) {
            id title { romaji english } coverImage { large }
            format status episodes seasonYear
          }
        }
      }
    `;
    const res = await fetch(ANILIST_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: gql, variables: { q: query, page } })
    });
    const { data } = await res.json();
    return data.Page.media.map(m => ({
      id: String(m.id),
      title: m.title.english ?? m.title.romaji,
      image: m.coverImage.large,
      year: m.seasonYear,
      format: m.format,
      totalEpisodes: m.episodes,
    }));
  },

  // ─── DETALLE ──────────────────────────────────────────────
  async getAnimeDetail(id: string): Promise<AnimeDetail> {
    const gql = `
      query($id: Int) {
        Media(id: $id, type: ANIME) {
          id idMal title { romaji english native } description
          coverImage { extraLarge } bannerImage format status episodes
          duration season seasonYear averageScore genres synonyms
          studios(isMain: true) { nodes { name } }
          startDate { year } endDate { year }
          nextAiringEpisode { episode airingAt }
        }
      }
    `;
    const res = await fetch(ANILIST_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: gql, variables: { id: parseInt(id) } })
    });
    const { data } = await res.json();
    const m = data.Media;
    return {
      id: String(m.id),
      title: m.title.english ?? m.title.romaji,
      titleAlternatives: [m.title.romaji, m.title.native, ...m.synonyms].filter(Boolean),
      synopsis: m.description?.replace(/<[^>]*>/g, '') ?? null, // strip HTML
      image: m.coverImage.extraLarge,
      banner: m.bannerImage,
      year: m.seasonYear,
      format: m.format,
      status: m.status,
      totalEpisodes: m.episodes,
      genres: m.genres,
      score: m.averageScore,
      studio: m.studios.nodes[0]?.name ?? null,
    };
  },

  // ─── EPISODIOS ────────────────────────────────────────────
  async getEpisodes(animeId: string, category: 'sub' | 'dub' = 'sub'): Promise<Episode[]> {
    const res = await fetch(`${EPISODES_API}/${animeId}`);
    const data = await res.json();

    // Prioridad de proveedores
    const providerOrder = ['kiwi', 'zoro', 'arc', 'jet'];
    for (const provider of providerOrder) {
      const episodes = data.providers?.[provider]?.episodes?.[category];
      if (episodes?.length > 0) {
        return episodes.map(ep => ({
          id: ep.id,
          number: ep.number,
          title: ep.title,
          thumbnail: ep.image,
          isFiller: ep.filler ?? false,
        }));
      }
    }
    return [];
  },

  // ─── SERVIDORES DEL EPISODIO ──────────────────────────────
  async getEpisodeServerLinks(episodeId: string): Promise<ServerLink[]> {
    // episodeId viene del formato: "watch/kiwi/178005/sub/animepahe-1"
    const res = await fetch(`${EPISODES_API}/../${episodeId}`);
    const data = await res.json();

    return data.streams.map((s, i) => ({
      id: `stream-${i}`,
      name: `Stream ${s.quality ?? i + 1}`,
      url: s.url,
      quality: s.quality,
      type: 'stream',
      headers: data.headers ?? { Referer: 'https://kwik.si/' },
    }));
  }
};
```

---

## 14. IMPLEMENTACIÓN DEL RESOLVER PLUGIN

Dado que Miruro entrega **M3U8 directamente** (no embeds de servicios externos), el "resolver" es simplemente un **passthrough** que añade los headers HTTP correctos.

```typescript
// miruro-resolver-plugin.ts (para Kumoriya)

export const KwikResolverPlugin = {
  id: 'kwik-resolver',
  name: 'Kwik.si / AnimePahe CDN',

  // Detectar si la URL es del CDN de Kwik
  supports(url: string): boolean {
    return url.includes('kwik.si')
        || url.includes('cdn.kwik.')
        || url.includes('animepahe.ru')
        || url.includes('animepahe.com');
  },

  // Ya es un M3U8 directo — solo añadir headers
  async resolve(url: string): Promise<ResolvedStream> {
    return {
      url,                    // URL ya es directamente reproducible
      type: 'hls',
      headers: {
        'Referer': 'https://kwik.si/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }
    };
  }
};

export const HiAnimeResolverPlugin = {
  id: 'hianime-resolver',
  name: 'HiAnime / MegaCloud CDN',

  supports(url: string): boolean {
    return url.includes('megacloud')
        || url.includes('megacdn')
        || url.includes('hianime')
        || url.includes('rapid-cloud');
  },

  async resolve(url: string): Promise<ResolvedStream> {
    return {
      url,
      type: 'hls',
      headers: {
        'Referer': 'https://hianime.to/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }
    };
  }
};
```

---

## 15. RESUMEN EJECUTIVO

### Flujo completo de datos para Kumoriya

```
1. Usuario busca "Naruto"
   └─→ search("naruto")
       └─→ AniList GraphQL → lista de animes con IDs

2. Usuario selecciona un anime (ej: id="20")
   └─→ getAnimeDetail("20")
       └─→ AniList GraphQL → metadata completo

3. Se cargan los episodios
   └─→ getEpisodes("20", "sub")
       └─→ Miruro-API /episodes/20 → lista de episodios
           (usa provider preferido: kiwi > zoro > arc)

4. Usuario hace clic en Episodio 1
   └─→ getEpisodeServerLinks("watch/kiwi/20/sub/animepahe-1")
       └─→ Miruro-API /watch/kiwi/20/sub/animepahe-1
           → { streams: [{url: "...master.m3u8"}], headers: {...} }

5. Kumoriya reproduce el M3U8
   └─→ KwikResolverPlugin.resolve("https://cdn.kwik.si/.../master.m3u8")
       → M3U8 + headers Referer → Player HLS
```

### Dependencias externas necesarias

| Dependencia | URL | Uso | Auth |
|---|---|---|---|
| AniList GraphQL | `graphql.anilist.co` | Metadata, búsqueda | ❌ No |
| Miruro-API (self-hosted) | `github.com/walterwhite-69/Miruro-API` | Episodios + Streams | ❌ No |
| Kwik.si CDN | Variable | Streams de AnimePahe | Header Referer |
| MegaCloud CDN | Variable | Streams de HiAnime | Header Referer |

### No requiere para funcionar
- ❌ Scraping HTML de miruro.tv (el JS no se ejecuta en el servidor)
- ❌ Descifrar el pipe AES-256 de Miruro
- ❌ Cuenta de usuario o API keys
- ❌ Resolvers de embed externos (VOE, Filemoon, etc. — Miruro no los usa)

---

*Documento generado para Kumoriya plugin development · miruro.tv · Junio 2026*
