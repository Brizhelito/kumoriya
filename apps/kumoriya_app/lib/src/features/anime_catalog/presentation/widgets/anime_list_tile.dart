import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';

class AnimeListTile extends StatelessWidget {
  const AnimeListTile({super.key, required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: _CoverImage(url: anime.coverImageUrl),
        title: Text(anime.title.romaji),
        subtitle: Text(
          [
            anime.format.name.toUpperCase(),
            if (anime.releaseYear != null) anime.releaseYear.toString(),
            if (anime.totalEpisodes != null)
              context.l10n.animeListEpisodesShort(anime.totalEpisodes!),
          ].join(' | '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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
      return const SizedBox(
        width: 56,
        height: 72,
        child: ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.movie_outlined),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url!,
        width: 56,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) {
          return const SizedBox(
            width: 56,
            height: 72,
            child: ColoredBox(
              color: Colors.black12,
              child: Icon(Icons.broken_image_outlined),
            ),
          );
        },
      ),
    );
  }
}
