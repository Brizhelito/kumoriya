import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../theme/kumoriya_theme.dart';
import 'kumoriya_cached_image.dart';

class AnimeCard extends StatelessWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.badge,
  });

  final Anime anime;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PosterImage(
            url: anime.coverImageUrl,
            title: anime.title.romaji,
            episodeCount: anime.totalEpisodes,
            badge: badge,
          ),
          const SizedBox(height: 8),
          Text(
            anime.title.romaji,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge!.copyWith(color: KumoriyaColors.textPrimary),
          ),
          if (anime.releaseYear != null)
            Text(
              anime.releaseYear.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(color: KumoriyaColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatefulWidget {
  const _PosterImage({
    required this.url,
    required this.title,
    this.episodeCount,
    this.badge,
  });

  final String? url;
  final String title;
  final int? episodeCount;
  final String? badge;

  @override
  State<_PosterImage> createState() => _PosterImageState();
}

class _PosterImageState extends State<_PosterImage> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AnimatedScale(
                scale: _hovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: KumoriyaCachedImage(
                  url: widget.url,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  fit: BoxFit.cover,
                ),
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.badge != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _CornerBadge(label: widget.badge!),
                ),
              if (widget.episodeCount != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _EpisodeCountBadge(count: widget.episodeCount!),
                ),
              if (_hovered)
                Center(
                  child: AnimatedScale(
                    scale: _hovered ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KumoriyaColors.primary.withValues(alpha: 0.90),
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: KumoriyaColors.primary.withValues(
                              alpha: 0.40,
                            ),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: KumoriyaColors.textPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: KumoriyaColors.primary,
        borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: KumoriyaColors.primary.withValues(alpha: 0.35),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: KumoriyaColors.textPrimary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EpisodeCountBadge extends StatelessWidget {
  const _EpisodeCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: KumoriyaColors.playerControlBg,
        borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Text(
        'Ep $count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: KumoriyaColors.textPrimary,
        ),
      ),
    );
  }
}
