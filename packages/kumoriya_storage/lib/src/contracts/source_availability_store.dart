import 'package:kumoriya_core/kumoriya_core.dart';

final class SourceAvailabilityCacheRecord {
  const SourceAvailabilityCacheRecord({
    required this.anilistId,
    required this.sourcePluginId,
    required this.payloadJson,
    required this.updatedAt,
  });

  final int anilistId;
  final String sourcePluginId;
  final String payloadJson;
  final DateTime updatedAt;
}

abstract interface class SourceAvailabilityStore {
  Future<Result<List<SourceAvailabilityCacheRecord>, KumoriyaError>>
  getAvailability(int anilistId);

  Future<Result<void, KumoriyaError>> replaceAvailability(
    int anilistId,
    List<SourceAvailabilityCacheRecord> records,
  );

  Future<Result<void, KumoriyaError>> clearAvailability(int anilistId);
}
