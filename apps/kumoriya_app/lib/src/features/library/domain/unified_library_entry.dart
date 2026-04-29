import 'package:kumoriya_core/kumoriya_core.dart';

/// A single library row that does not care about its universe.
///
/// Composed by `UnifiedLibraryService` from anime + manga library
/// stores so the Library UI can render both universes as one
/// chronological / alphabetical inventory. Carrying [mediaKind]
/// disambiguates the two domains the user perceives as one
/// ("my list").
final class UnifiedLibraryEntry {
  const UnifiedLibraryEntry({
    required this.mediaKind,
    required this.anilistId,
    required this.title,
    this.coverImageUrl,
  });

  final MediaKind mediaKind;
  final int anilistId;
  final String title;
  final String? coverImageUrl;

  @override
  bool operator ==(Object other) =>
      other is UnifiedLibraryEntry &&
      other.mediaKind == mediaKind &&
      other.anilistId == anilistId;

  @override
  int get hashCode => Object.hash(mediaKind, anilistId);
}
