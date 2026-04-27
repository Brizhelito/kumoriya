import 'manga_country_of_origin.dart';
import 'manga_format.dart';
import 'manga_sort.dart';
import 'manga_status.dart';

/// Browse query against the AniList-canonical manga catalog.
///
/// Mirrors `AnimeBrowseRequest` minus seasonal filters (manga has no
/// seasons) and plus `countriesOfOrigin` (lets the UI filter "manhwa
/// only" / "manhua only" feeds without inventing format heuristics).
final class MangaBrowseRequest {
  const MangaBrowseRequest({
    this.search,
    this.genres,
    this.tags,
    this.formats,
    this.statuses,
    this.countriesOfOrigin,
    this.sort = MangaSortType.trending,
    this.page = 1,
    this.perPage = 20,
  });

  final String? search;
  final List<String>? genres;
  final List<String>? tags;
  final List<MangaFormat>? formats;
  final List<MangaStatus>? statuses;
  final List<MangaCountryOfOrigin>? countriesOfOrigin;
  final MangaSortType sort;
  final int page;
  final int perPage;

  MangaBrowseRequest copyWith({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<MangaFormat>? formats,
    List<MangaStatus>? statuses,
    List<MangaCountryOfOrigin>? countriesOfOrigin,
    MangaSortType? sort,
    int? page,
    int? perPage,
  }) {
    return MangaBrowseRequest(
      search: search ?? this.search,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      formats: formats ?? this.formats,
      statuses: statuses ?? this.statuses,
      countriesOfOrigin: countriesOfOrigin ?? this.countriesOfOrigin,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MangaBrowseRequest) return false;
    return search == other.search &&
        _listEquals(genres, other.genres) &&
        _listEquals(tags, other.tags) &&
        _listEquals(formats, other.formats) &&
        _listEquals(statuses, other.statuses) &&
        _listEquals(countriesOfOrigin, other.countriesOfOrigin) &&
        sort == other.sort &&
        page == other.page &&
        perPage == other.perPage;
  }

  @override
  int get hashCode => Object.hash(
    search,
    genres != null ? Object.hashAll(genres!) : null,
    tags != null ? Object.hashAll(tags!) : null,
    formats != null ? Object.hashAll(formats!) : null,
    statuses != null ? Object.hashAll(statuses!) : null,
    countriesOfOrigin != null ? Object.hashAll(countriesOfOrigin!) : null,
    sort,
    page,
    perPage,
  );
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
