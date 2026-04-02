import 'anime_format.dart';
import 'anime_season.dart';
import 'anime_sort.dart';
import 'anime_status.dart';

final class AnimeBrowseRequest {
  const AnimeBrowseRequest({
    this.search,
    this.genres,
    this.tags,
    this.formats,
    this.season,
    this.seasonYear,
    this.statuses,
    this.sort = AnimeSortType.trending,
    this.page = 1,
    this.perPage = 20,
  });

  final String? search;
  final List<String>? genres;
  final List<String>? tags;
  final List<AnimeFormat>? formats;
  final AnimeSeason? season;
  final int? seasonYear;
  final List<AnimeStatus>? statuses;
  final AnimeSortType sort;
  final int page;
  final int perPage;

  AnimeBrowseRequest copyWith({
    String? search,
    List<String>? genres,
    List<String>? tags,
    List<AnimeFormat>? formats,
    AnimeSeason? season,
    int? seasonYear,
    List<AnimeStatus>? statuses,
    AnimeSortType? sort,
    int? page,
    int? perPage,
  }) {
    return AnimeBrowseRequest(
      search: search ?? this.search,
      genres: genres ?? this.genres,
      tags: tags ?? this.tags,
      formats: formats ?? this.formats,
      season: season ?? this.season,
      seasonYear: seasonYear ?? this.seasonYear,
      statuses: statuses ?? this.statuses,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnimeBrowseRequest) return false;
    return search == other.search &&
        _listEquals(genres, other.genres) &&
        _listEquals(tags, other.tags) &&
        _listEquals(formats, other.formats) &&
        season == other.season &&
        seasonYear == other.seasonYear &&
        _listEquals(statuses, other.statuses) &&
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
    season,
    seasonYear,
    statuses != null ? Object.hashAll(statuses!) : null,
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
