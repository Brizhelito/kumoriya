/// Common URL helpers used across resolver plugins.

/// Convert a potentially relative URL to absolute using [baseUrl] as context.
///
/// Returns null if the input cannot be parsed to a valid absolute URI.
Uri? toAbsoluteUri(String raw, Uri baseUrl) {
  final parsed = Uri.tryParse(raw);
  if (parsed == null) return null;

  if (parsed.hasScheme && parsed.host.isNotEmpty) return parsed;

  if (raw.startsWith('//')) {
    return Uri.tryParse('${baseUrl.scheme}:$raw');
  }

  if (raw.startsWith('/')) {
    return baseUrl.replace(path: raw, query: null, fragment: null);
  }

  return null;
}

/// Whether the URI points to a playable stream (HLS or MP4).
bool isPlayableUri(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final value = uri.toString().toLowerCase();
  return value.contains('.m3u8') ||
      value.contains('.mp4') ||
      value.contains('/hls/');
}

/// Infer a quality label from a stream URL.
///
/// Detects standard resolution labels (2160p–360p) from URL path/query,
/// returns `'auto'` for HLS manifests, or `'unknown'` if nothing matches.
String inferQualityFromUrl(Uri uri) {
  final match = _qualityRe.firstMatch(uri.toString().toLowerCase());
  if (match != null) return '${match.group(1)}p';
  if (uri.toString().toLowerCase().contains('.m3u8')) return 'auto';
  return 'unknown';
}

final _qualityRe = RegExp(r'(2160|1440|1080|720|480|360)p');

/// Check if a host string matches any in [knownHosts] (exact or subdomain).
bool isHostSupported(String host, Set<String> knownHosts) {
  final normalized = host.toLowerCase();
  return knownHosts.any(
    (supported) =>
        normalized == supported || normalized.endsWith('.$supported'),
  );
}

/// Build standard embed request headers with Referer and Origin.
Map<String, String> buildEmbedHeaders(Uri url, {Uri? referer}) {
  final origin = '${url.scheme}://${url.host}';
  return <String, String>{
    'Referer': referer?.toString() ?? '$origin/',
    'Origin': origin,
  };
}
