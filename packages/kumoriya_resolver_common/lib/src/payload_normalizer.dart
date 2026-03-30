/// Common payload normalization for resolver embed HTML/JS responses.
///
/// Nearly every resolver applies the same escaping cleanup before extraction.

final _normalizeRe = RegExp(r'\\/|&amp;|\\u0026|\\x2F');

const _normalizeMap = <String, String>{
  r'\/': '/',
  '&amp;': '&',
  r'\u0026': '&',
  r'\x2F': '/',
};

/// Normalize common escape sequences found in embed payloads.
///
/// Handles: `\/` → `/`, `&amp;` → `&`, `\u0026` → `&`, `\x2F` → `/`.
/// Single-pass replacement via regex.
String normalizePayload(String payload) {
  return payload.replaceAllMapped(
    _normalizeRe,
    (m) => _normalizeMap[m[0]!] ?? m[0]!,
  );
}

final _htmlUnescapeRe = RegExp(r'&quot;|&#34;|&#39;|&amp;|&lt;|&gt;');

const _htmlUnescapeMap = <String, String>{
  '&quot;': '"',
  '&#34;': '"',
  '&#39;': "'",
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
};

/// Unescape common HTML entities. Single-pass replacement.
String htmlUnescape(String value) {
  return value.replaceAllMapped(
    _htmlUnescapeRe,
    (m) => _htmlUnescapeMap[m[0]!] ?? m[0]!,
  );
}
