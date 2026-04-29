import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/mangaupdates_group.dart';
import '../models/mangaupdates_release.dart';
import '../models/mangaupdates_series.dart';

/// High-level gateway for MangaUpdates metadata. The application
/// layer depends on this contract; the HTTP-backed implementation
/// lives in the gateway folder.
///
/// Note: MangaUpdates uses **numeric** `series_id` and `group_id`
/// values that exceed the 32-bit range. Callers must persist them as
/// 64-bit integers.
abstract interface class MangaUpdatesMetadataGateway {
  /// Free-text search over MangaUpdates series. The returned list
  /// preserves the API order (relevance-ranked). Returns an empty
  /// list without hitting the network when [query] is empty.
  Future<Result<List<MangaUpdatesSeries>, KumoriyaError>> searchSeries({
    required String query,
    int page = 1,
    int perPage = 25,
  });

  /// Fetches a single series by numeric `series_id`. The detail
  /// endpoint exposes additional fields (associated titles,
  /// completed/licensed flags, latest_chapter, status note) that
  /// search hits omit.
  Future<Result<MangaUpdatesSeries, KumoriyaError>> fetchSeriesById(int id);

  /// Fetches a single scanlator group by numeric `group_id`. The
  /// canonical surface for picker enrichment (M8) — exposes the
  /// `active` flag plus social/site URLs.
  Future<Result<MangaUpdatesGroup, KumoriyaError>> fetchGroupById(int id);

  /// Searches releases with optional series-id filtering. Used by
  /// the picker enrichment slice (M8) to compute "last activity per
  /// scanlator on this series" and "lifetime release count per
  /// group on this series".
  Future<Result<List<MangaUpdatesRelease>, KumoriyaError>> searchReleases({
    int? seriesId,
    int? groupId,
    int page = 1,
    int perPage = 25,
  });
}
