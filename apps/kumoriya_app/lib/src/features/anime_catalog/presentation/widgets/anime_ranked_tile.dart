import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';

class AnimeRankedTile extends StatefulWidget {
  const AnimeRankedTile({
    super.key,
    required this.anime,
    required this.rank,
    required this.onTap,
  });

  final Anime anime;
  final int rank;
  final VoidCallback onTap;

  @override
  State<AnimeRankedTile> createState() => _AnimeRankedTileState();
}

class _AnimeRankedTileState extends State<AnimeRankedTile> {
  bool _hovered = false;

  static final _rankStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: KumoriyaColors.primary.withValues(alpha: 0.50),
    fontStyle: FontStyle.italic,
  );

  static final _scoreStyle = TextStyle(
    fontSize: 11,
    color: KumoriyaColors.accentAmber,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        splashColor: KumoriyaColors.primary.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surfaceDim,
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Text(
                  '${widget.rank}',
                  textAlign: TextAlign.center,
                  style: _rankStyle,
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                child: KumoriyaCachedImage(
                  url: widget.anime.coverImageUrl,
                  bucket: KumoriyaImageCacheBucket.artwork,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.anime.title.romaji,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        if (widget.anime.releaseYear != null) ...<Widget>[
                          Text(
                            '${widget.anime.releaseYear}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: KumoriyaColors.textDisabled,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: KumoriyaColors.borderMedium,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          widget.anime.format.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: KumoriyaColors.textDisabled,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (widget.anime.averageScore != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: KumoriyaColors.borderMedium,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '★ ${widget.anime.averageScore}',
                            style: _scoreStyle,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: KumoriyaColors.textDisabled,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
