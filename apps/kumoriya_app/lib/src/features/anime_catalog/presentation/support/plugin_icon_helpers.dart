import 'package:kumoriya_plugins/kumoriya_plugins.dart';

/// Returns the best available icon URL for a source plugin.
///
/// Priority:
/// 1. Explicit [PluginManifest.iconUrl] if non-empty.
/// 2. Favicon derived from the first [PluginManifest.baseUrls] entry.
/// 3. `null` (callers fall back to initial-letter avatar).
String? effectiveSourceIconUrl(PluginManifest manifest) {
  if (manifest.iconUrl != null && manifest.iconUrl!.trim().isNotEmpty) {
    return manifest.iconUrl;
  }
  if (manifest.baseUrls.isNotEmpty) {
    final base = manifest.baseUrls.first;
    final uri = Uri.tryParse(base);
    if (uri != null && uri.hasScheme) {
      return '${uri.scheme}://${uri.host}/favicon.ico';
    }
  }
  return null;
}
