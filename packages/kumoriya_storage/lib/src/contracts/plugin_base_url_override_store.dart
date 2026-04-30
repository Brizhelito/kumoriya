import 'package:kumoriya_core/kumoriya_core.dart';

/// Snapshot of a single per-plugin base-URL override.
final class PluginBaseUrlOverride {
  const PluginBaseUrlOverride({
    required this.pluginId,
    required this.baseUrl,
    required this.updatedAt,
  });

  final String pluginId;
  final Uri baseUrl;
  final DateTime updatedAt;
}

/// Persistence contract for per-plugin user overrides of the active base URL.
///
/// Manifests stay the source of truth for the *list* of mirrors. This store
/// only records that the user has promoted one URL ahead of the manifest
/// list. Cleared rows revert to manifest default order.
abstract interface class PluginBaseUrlOverrideStore {
  Future<Result<List<PluginBaseUrlOverride>, KumoriyaError>> getAll();

  Future<Result<PluginBaseUrlOverride?, KumoriyaError>> get(String pluginId);

  Future<Result<void, KumoriyaError>> set({
    required String pluginId,
    required Uri baseUrl,
  });

  Future<Result<void, KumoriyaError>> clear(String pluginId);
}
