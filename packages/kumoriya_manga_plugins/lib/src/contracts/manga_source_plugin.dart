import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/manga_chapter_query.dart';
import '../models/manga_search_query.dart';
import '../models/manga_source_capabilities.dart';
import '../models/source_chapter.dart';
import '../models/source_manga_detail.dart';
import '../models/source_manga_match.dart';
import '../models/source_page.dart';

/// Contract every manga source must implement.
///
/// Parallel to `SourcePlugin` (anime). Kept separate because
/// chapter/page semantics differ enough from episode/stream
/// semantics that conflating both would force compromises:
///
/// - chapters carry `language` + `scanlator` — episodes don't,
/// - pages are direct image URLs with optional per-request headers
///   — episode streams flow through a resolver step,
/// - chapter numbers are fractional (`12.5`) — episodes are integers
///   in practice across all current anime sources.
///
/// Implementations:
///
/// - MUST be safe to call concurrently. Internal state, if any, must
///   be guarded.
/// - MUST NOT throw across the contract boundary; failures are
///   reported via `Result.failure(KumoriyaError)`.
/// - MUST return stable `sourceId` / `sourceMangaId` /
///   `sourceChapterId` values across the lifetime of an installation,
///   so storage rows keyed by them survive across launches.
abstract interface class MangaSourcePlugin {
  /// Static manifest reused from `kumoriya_plugins`. The `type` field
  /// is always `PluginType.source`.
  PluginManifest get manifest;

  /// Manga-specific feature flags. The contract layer never
  /// introspects this — it's read by the UI / repository layer to
  /// decide which filters to surface and which network primitives to
  /// engage.
  MangaSourceCapabilities get mangaCapabilities;

  /// Free-text search.
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> search(
    MangaSearchQuery query,
  );

  /// Latest chapter releases feed, when the source supports it
  /// (`MangaSourceCapabilities.supportsLatestFeed == true`).
  ///
  /// Plugins that do not support a latest feed MUST return
  /// `Result.success(<empty>)`, not a failure.
  Future<Result<List<SourceMangaMatch>, KumoriyaError>> getLatestUpdates({
    int page = 1,
    int limit = 20,
  });

  /// Detail page for a single manga.
  Future<Result<SourceMangaDetail, KumoriyaError>> getMangaDetail(
    String sourceMangaId,
  );

  /// Chapter list for a manga, possibly filtered by language /
  /// scanlator when the plugin supports it. Returns chapters in
  /// source order; callers re-sort if they need ascending/descending
  /// `number`.
  Future<Result<List<SourceChapter>, KumoriyaError>> getChapters(
    MangaChapterQuery query,
  );

  /// Pages of a single chapter, in render order.
  ///
  /// The returned list MUST be index-contiguous (`pages[i].index == i`)
  /// and MUST contain at least one page on success. If the source
  /// reveals an empty chapter, return
  /// `Result.failure(KumoriyaError(...))` rather than an empty success.
  Future<Result<List<SourcePage>, KumoriyaError>> getChapterPages(
    SourceChapter chapter,
  );
}
