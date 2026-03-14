function parseAnimeNexusPathParts(url) {
  const last = url.pathname.split("/").filter(Boolean).at(-1) ?? "";
  const match =
    /_(\d+)(?:_(?:\d+|init|[a-z]+))?-(\d+)\.(?:m3u8|mp4|m4s|ts)$/i.exec(last);
  if (!match) return null;
  return {
    variant: match[1],
    track: Number(match[2]),
  };
}

function parseAttributes(raw) {
  const result = {};
  const regex = /([A-Z0-9-]+)=((?:\"[^\"]*\")|[^,]*)/g;
  for (const match of raw.matchAll(regex)) {
    const key = match[1];
    const rawValue = match[2] ?? "";
    result[key] =
      rawValue.startsWith('"') && rawValue.endsWith('"')
        ? rawValue.slice(1, -1)
        : rawValue;
  }
  return result;
}

function trackFromPath(url) {
  const animeNexusParts = parseAnimeNexusPathParts(url);
  if (animeNexusParts) return animeNexusParts.track;
  const last = url.pathname.split("/").filter(Boolean).at(-1) ?? "";
  const match = /^(\d+)\.m3u8$/i.exec(last);
  return match ? Number(match[1]) : 0;
}

function variantFromPath(url, qualityLabel) {
  const animeNexusParts = parseAnimeNexusPathParts(url);
  if (animeNexusParts) return animeNexusParts.variant;
  const parts = url.pathname.split("/").filter(Boolean);
  for (let index = parts.length - 2; index >= 0; index -= 1) {
    if (/^\d+$/.test(parts[index])) {
      return parts[index];
    }
  }
  const fallback = (qualityLabel ?? "").replace(/[^0-9]/g, "");
  return fallback || "default";
}

export function parseMasterManifest(content, baseUrl) {
  const base = new URL(baseUrl);
  const lines = content.split(/\r?\n/);
  const streamEntries = [];
  const audioEntries = [];

  for (let index = 0; index < lines.length; index += 1) {
    const rawLine = lines[index];
    const line = rawLine.trim();
    if (!line) continue;

    if (line.startsWith("#EXT-X-MEDIA:")) {
      const attrs = parseAttributes(line.slice("#EXT-X-MEDIA:".length));
      if ((attrs.TYPE ?? "").toUpperCase() !== "AUDIO" || !attrs.URI) {
        continue;
      }
      const uri = new URL(attrs.URI, base);
      audioEntries.push({
        uri,
        groupId: attrs["GROUP-ID"] ?? null,
        originalLine: rawLine,
        metadata: {
          variant: variantFromPath(uri, attrs.NAME),
          track: trackFromPath(uri),
        },
      });
      continue;
    }

    if (line.startsWith("#EXT-X-STREAM-INF:")) {
      const infoLine = rawLine;
      const attrs = parseAttributes(line.slice("#EXT-X-STREAM-INF:".length));
      const nextLine = lines[index + 1]?.trim() ?? "";
      if (!nextLine || nextLine.startsWith("#")) {
        continue;
      }
      const uri = new URL(nextLine, base);
      const qualityLabel =
        attrs.RESOLUTION?.split("x")?.[1] ?? variantFromPath(uri, null);
      streamEntries.push({
        uri,
        infoLine,
        qualityLabel,
        audioGroupId: attrs.AUDIO ?? null,
        metadata: {
          variant: variantFromPath(uri, qualityLabel),
          track: trackFromPath(uri),
        },
      });
    }
  }

  return { streamEntries, audioEntries };
}
