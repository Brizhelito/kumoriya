import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';

class EpisodeListPage extends ConsumerWidget {
  const EpisodeListPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
  });

  final int anilistId;
  final String animeTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesState = ref.watch(animeEpisodesProvider(anilistId));

    return Scaffold(
      appBar: AppBar(title: Text('$animeTitle episodes')),
      body: episodesState.when(
        loading: () => const LoadingStateView(label: 'Loading episodes...'),
        error: (error, _) => ErrorStateView(
          message: 'Unexpected state error: $error',
          onRetry: () => ref.invalidate(animeEpisodesProvider(anilistId)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(error),
            onRetry: () => ref.invalidate(animeEpisodesProvider(anilistId)),
          ),
          onSuccess: (episodes) {
            if (episodes.isEmpty) {
              return const EmptyStateView(
                message: 'AniList has no episode metadata for this anime yet.',
              );
            }

            return ListView.separated(
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final episode = episodes[index];
                return ListTile(
                  title: Text('${episode.number.toInt()}. ${episode.title}'),
                  subtitle: Text(
                    episode.isAired ? 'Aired metadata' : 'Upcoming metadata',
                    style: TextStyle(
                      color: episode.isAired ? Colors.green : Colors.orange,
                    ),
                  ),
                  trailing: episode.airDate != null
                      ? Text(
                          '${episode.airDate!.toLocal().year}-${episode.airDate!.toLocal().month.toString().padLeft(2, '0')}-${episode.airDate!.toLocal().day.toString().padLeft(2, '0')}',
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
