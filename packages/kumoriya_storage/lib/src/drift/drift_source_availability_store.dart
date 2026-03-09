import 'package:drift/drift.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../contracts/source_availability_store.dart';
import 'app_database.dart';
import 'daos/source_availability_cache_dao.dart';

final class DriftSourceAvailabilityStore implements SourceAvailabilityStore {
  DriftSourceAvailabilityStore(AppDatabase db)
    : _dao = SourceAvailabilityCacheDao(db);

  final SourceAvailabilityCacheDao _dao;

  @override
  Future<Result<List<SourceAvailabilityCacheRecord>, KumoriyaError>>
  getAvailability(int anilistId) async {
    try {
      final rows = await _dao.getAvailability(anilistId);
      return Success(
        rows
            .map(
              (row) => SourceAvailabilityCacheRecord(
                anilistId: row.anilistId,
                sourcePluginId: row.sourcePluginId,
                payloadJson: row.payloadJson,
                updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
              ),
            )
            .toList(growable: false),
      );
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.source_availability_read_failed',
          message: 'Failed to read source availability cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> replaceAvailability(
    int anilistId,
    List<SourceAvailabilityCacheRecord> records,
  ) async {
    try {
      await _dao.replaceAvailability(
        anilistId,
        records
            .map(
              (record) => SourceAvailabilityCacheTableCompanion(
                anilistId: Value(record.anilistId),
                sourcePluginId: Value(record.sourcePluginId),
                payloadJson: Value(record.payloadJson),
                updatedAt: Value(record.updatedAt.millisecondsSinceEpoch),
              ),
            )
            .toList(growable: false),
      );
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.source_availability_write_failed',
          message: 'Failed to store source availability cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }

  @override
  Future<Result<void, KumoriyaError>> clearAvailability(int anilistId) async {
    try {
      await _dao.clearAvailability(anilistId);
      return const Success(null);
    } catch (e) {
      return Failure(
        SimpleError(
          code: 'storage.source_availability_clear_failed',
          message: 'Failed to clear source availability cache: $e',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
  }
}
