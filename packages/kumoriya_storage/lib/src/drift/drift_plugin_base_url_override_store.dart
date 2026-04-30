import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/plugin_base_url_override_store.dart';
import 'app_database.dart';
import 'daos/plugin_base_url_override_dao.dart';

final class DriftPluginBaseUrlOverrideStore
    implements PluginBaseUrlOverrideStore {
  DriftPluginBaseUrlOverrideStore(AppDatabase db)
    : _dao = PluginBaseUrlOverrideDao(db);

  final PluginBaseUrlOverrideDao _dao;

  @override
  Future<Result<List<PluginBaseUrlOverride>, KumoriyaError>> getAll() async {
    try {
      final rows = await _dao.getAllOverrides();
      return Success(rows.map(_toOverride).toList(growable: false));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.plugin_base_url_override_read_failed',
          message: 'Failed to read base-URL overrides: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<PluginBaseUrlOverride?, KumoriyaError>> get(
    String pluginId,
  ) async {
    try {
      final row = await _dao.getOverride(pluginId);
      return Success(row == null ? null : _toOverride(row));
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.plugin_base_url_override_read_failed',
          message: 'Failed to read base-URL override for $pluginId: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> set({
    required String pluginId,
    required Uri baseUrl,
  }) async {
    if (pluginId.isEmpty) {
      return Failure(
        SimpleError(
          code: 'storage.plugin_base_url_override_invalid_plugin',
          message: 'pluginId must not be empty',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
    if (!baseUrl.isAbsolute ||
        (baseUrl.scheme != 'http' && baseUrl.scheme != 'https')) {
      return Failure(
        SimpleError(
          code: 'storage.plugin_base_url_override_invalid_url',
          message: 'baseUrl must be an absolute http(s) URL: $baseUrl',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
    try {
      await _dao.setOverride(
        pluginId: pluginId,
        baseUrl: baseUrl.toString(),
        updatedAt: DateTime.now(),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.plugin_base_url_override_write_failed',
          message: 'Failed to persist base-URL override: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clear(String pluginId) async {
    try {
      await _dao.clearOverride(pluginId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.plugin_base_url_override_delete_failed',
          message: 'Failed to clear base-URL override: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  PluginBaseUrlOverride _toOverride(PluginBaseUrlOverrideTableData row) {
    return PluginBaseUrlOverride(
      pluginId: row.pluginId,
      baseUrl: Uri.parse(row.baseUrl),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
