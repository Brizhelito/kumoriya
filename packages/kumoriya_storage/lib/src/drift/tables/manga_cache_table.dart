import 'package:drift/drift.dart';

/// Local cache mirror of AniList manga metadata.
///
/// Parallel to `AnilistCacheTable` (which is anime-only). Manga-specific
/// fields (`totalChapters`, `totalVolumes`, `countryOfOrigin`,
/// `originalLanguage`) live as typed columns instead of stuffing a
/// `mediaKind` discriminator onto the anime cache.
class MangaCacheTable extends Table {
  @override
  String get tableName => 'manga_cache';

  IntColumn get anilistId => integer()();
  TextColumn get titleRomaji => text()();
  TextColumn get titleEnglish => text().nullable()();
  TextColumn get titleNative => text().nullable()();

  /// JSON-encoded `List<String>`.
  TextColumn get synonyms => text().nullable()();

  TextColumn get coverImageUrl => text().nullable()();
  TextColumn get bannerImageUrl => text().nullable()();

  /// AniList release status string (`RELEASING`, `FINISHED`, `HIATUS`,
  /// `CANCELLED`, `NOT_YET_RELEASED`).
  TextColumn get status => text().nullable()();

  /// AniList format string (`MANGA`, `MANHWA`, `MANHUA`, `ONE_SHOT`,
  /// `DOUJINSHI`, `NOVEL`).
  TextColumn get format => text().nullable()();

  /// ISO 3166 country code: `JP`, `KR`, `CN`, `TW`.
  TextColumn get countryOfOrigin => text().nullable()();

  /// BCP-47 language tag of the original publication when known
  /// (`ja`, `ko`, `zh`).
  TextColumn get originalLanguage => text().nullable()();

  IntColumn get releaseYear => integer().nullable()();
  IntColumn get totalChapters => integer().nullable()();
  IntColumn get totalVolumes => integer().nullable()();
  IntColumn get averageScore => integer().nullable()();
  IntColumn get popularity => integer().nullable()();

  /// JSON-encoded `List<String>`.
  TextColumn get genres => text().nullable()();

  /// JSON-encoded `List<{name, rank?, isAdult?}>`.
  TextColumn get tags => text().nullable()();

  TextColumn get synopsis => text().nullable()();

  /// JSON-encoded `List<{id, type, mediaKind}>` of relations.
  TextColumn get relations => text().nullable()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {anilistId};
}
