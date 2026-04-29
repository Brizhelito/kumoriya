import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/mangabaka_series.dart';

/// High-level gateway for MangaBaka metadata. The application layer
/// depends on this contract; the HTTP-backed implementation lives in
/// the gateway folder.
abstract interface class MangaBakaMetadataGateway {
  /// Free-text search over MangaBaka. The returned list preserves the
  /// API order (relevance-ranked by MangaBaka). When [query] is empty
  /// the gateway returns an empty list without hitting the network.
  Future<Result<List<MangaBakaSeries>, KumoriyaError>> searchSeries({
    required String query,
    int limit = 20,
    int page = 1,
  });

  /// Fetches a single series by MangaBaka id. When the requested row
  /// is in the `merged` state and [followMerges] is true, the gateway
  /// transparently follows the redirect to the canonical row (one hop
  /// only, to keep latency bounded).
  Future<Result<MangaBakaSeries, KumoriyaError>> fetchSeriesById(
    int id, {
    bool followMerges = true,
  });
}
