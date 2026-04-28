import 'package:flutter/material.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';

/// Vertical poster card for a manga: cover (3:4) + title + score chip.
///
/// Tap surfaces the detail page (caller wires `onTap`). The cover uses
/// the standard cached image bucket so artwork is shared with anime.
///
/// The card has a deterministic intrinsic height — `posterHeight(width)`
/// — so callers (carousels, grids) can size their viewport without
/// guess-work or empirical cushions:
///
///     final h = MangaCard.heightFor(width);
class MangaCard extends StatelessWidget {
  /// Height of the title block (2 lines @ labelLarge).
  static const double _titleBlockHeight = 38;

  /// Height of the year block (1 line @ bodySmall).
  static const double _yearBlockHeight = 16;

  /// Vertical gap between poster and title.
  static const double _posterGap = 8;

  /// Total height the card occupies for a given poster `width`.
  /// Always reserves the year row so cards align inside a carousel
  /// regardless of which entries have a `releaseYear`.
  static double heightFor(double width) =>
      width * (4 / 3) + _posterGap + _titleBlockHeight + _yearBlockHeight;

  const MangaCard({
    super.key,
    required this.manga,
    required this.onTap,
    this.width,
  });

  final Manga manga;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                KumoriyaCachedImage(
                  url: manga.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  fit: BoxFit.cover,
                ),
                if (manga.averageScore != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _ScoreChip(score: manga.averageScore!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _posterGap),
        SizedBox(
          height: _titleBlockHeight,
          child: Text(
            manga.title.romaji,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge!.copyWith(
              color: KumoriyaColors.textPrimary,
              height: 1.15,
            ),
          ),
        ),
        SizedBox(
          height: _yearBlockHeight,
          child: manga.releaseYear == null
              ? null
              : Text(
                  manga.releaseYear!.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall!.copyWith(
                    color: KumoriyaColors.textMuted,
                  ),
                ),
        ),
      ],
    );
    final tappable = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      child: card,
    );
    if (width != null) {
      return SizedBox(width: width, child: tappable);
    }
    return tappable;
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, color: Color(0xFFE8C36A), size: 14),
          const SizedBox(width: 2),
          Text(
            (score / 10).toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
