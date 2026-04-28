import 'package:flutter/material.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import 'manga_card.dart';

/// Horizontal "shelf" carousel of manga cards. Used by the manga Home
/// for Trending / Popular / Latest / Top Rated sections.
class MangaCarousel extends StatelessWidget {
  const MangaCarousel({
    super.key,
    required this.title,
    required this.manga,
    required this.onMangaTap,
    this.cardWidth = 132,
  });

  final String title;
  final List<Manga> manga;
  final void Function(Manga) onMangaTap;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    if (manga.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: textTheme.titleLarge!.copyWith(
              color: KumoriyaColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: cardWidth * (4 / 3) + 56, // poster + title + year line
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, i) => MangaCard(
              manga: manga[i],
              onTap: () => onMangaTap(manga[i]),
              width: cardWidth,
            ),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: manga.length,
          ),
        ),
      ],
    );
  }
}
