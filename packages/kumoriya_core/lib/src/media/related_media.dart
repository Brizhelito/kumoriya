import 'media_kind.dart';

final class RelatedMedia {
  const RelatedMedia({
    required this.kind,
    required this.anilistId,
    required this.titleRomaji,
    this.titleEnglish,
    this.titleNative,
    this.coverImageUrl,
    this.bannerImageUrl,
    this.formatLabel,
  });

  final MediaKind kind;
  final int anilistId;
  final String titleRomaji;
  final String? titleEnglish;
  final String? titleNative;
  final String? coverImageUrl;
  final String? bannerImageUrl;
  final String? formatLabel;
}
