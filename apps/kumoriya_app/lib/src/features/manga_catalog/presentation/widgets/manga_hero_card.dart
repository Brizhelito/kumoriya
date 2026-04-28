import 'package:flutter/material.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';

/// Featured banner-style hero card. Shows the banner image (or cover as
/// fallback), title, score, and a primary action.
class MangaHeroCard extends StatelessWidget {
  const MangaHeroCard({
    super.key,
    required this.manga,
    required this.featuredLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final Manga manga;
  final String featuredLabel;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final imageUrl = manga.bannerImageUrl ?? manga.coverImageUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        child: AspectRatio(
          // 21:9 (cinema) keeps the hero impactful but ~30% shorter than
          // 16:9, so on a 360dp phone roughly 1.5 carousels are visible
          // below the hero without scrolling — the previous 16:9 left
          // only the first carousel above the fold and made the home
          // feel half-empty.
          aspectRatio: 21 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              KumoriyaCachedImage(
                url: imageUrl,
                bucket: KumoriyaImageCacheBucket.artwork,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(
                          KumoriyaRadius.full,
                        ),
                      ),
                      child: Text(
                        featuredLabel,
                        style: textTheme.labelSmall!.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      manga.title.romaji,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
