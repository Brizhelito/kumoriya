import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';

class AnimeListTile extends StatelessWidget {
  const AnimeListTile({super.key, required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: KumoriyaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KumoriyaRadius.xxl)),
      child: InkWell(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              _CoverImage(url: anime.coverImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      anime.title.romaji,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _MetaChip(label: anime.format.name.toUpperCase()),
                        if (anime.releaseYear != null)
                          _MetaChip(label: anime.releaseYear.toString()),
                        if (anime.totalEpisodes != null)
                          _MetaChip(
                            label: context.l10n.animeListEpisodesShort(
                              anime.totalEpisodes!,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: KumoriyaColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: 68,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: KumoriyaColors.borderSubtle,
        ),
        child: const Icon(Icons.movie_outlined),
      );
    }

    return KumoriyaCachedImage(
      url: url,
      bucket: KumoriyaImageCacheBucket.artwork,
      width: 68,
      height: 92,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(16),
      errorFallback: Container(
        width: 68,
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: KumoriyaColors.borderSubtle,
        ),
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: KumoriyaColors.borderSubtle,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
