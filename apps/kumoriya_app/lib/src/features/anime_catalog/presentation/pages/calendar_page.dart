import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/kumoriya_cached_image.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import 'anime_detail_page.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogState = ref.watch(homeCatalogProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: KumoriyaColors.textPrimary,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Currently airing',
                style: TextStyle(fontSize: 13, color: KumoriyaColors.textMuted),
              ),
            ),
            Expanded(
              child: catalogState.when(
                loading: () => const LoadingStateView(),
                error: (_, _) => ErrorStateView(
                  message: context.l10n.genericLoadFailure,
                  onRetry: () => ref.invalidate(homeCatalogProvider),
                ),
                data: (result) => result.fold(
                  onFailure: (error) => ErrorStateView(
                    message: mapErrorMessage(context, error),
                    onRetry: () => ref.invalidate(homeCatalogProvider),
                  ),
                  onSuccess: (animeList) {
                    final airing = animeList
                        .where(
                          (a) =>
                              a.status == AnimeStatus.releasing ||
                              a.status == AnimeStatus.notYetReleased,
                        )
                        .toList(growable: false);

                    if (airing.isEmpty) {
                      return const EmptyStateView(
                        message: 'No airing anime found.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: airing.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final anime = airing[index];
                        return _AiringRow(
                          anime: anime,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AnimeDetailPage(anilistId: anime.anilistId),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiringRow extends StatefulWidget {
  const _AiringRow({required this.anime, required this.onTap});

  final Anime anime;
  final VoidCallback onTap;

  @override
  State<_AiringRow> createState() => _AiringRowState();
}

class _AiringRowState extends State<_AiringRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? KumoriyaColors.surface
                : KumoriyaColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(KumoriyaRadius.xxl),
            border: Border.all(
              color: _hovered
                  ? KumoriyaColors.borderMedium
                  : KumoriyaColors.borderSubtle,
            ),
          ),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(KumoriyaRadius.md),
                child: KumoriyaCachedImage(
                  url: anime.coverImageUrl,
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
                      anime.title.romaji,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: KumoriyaColors.textPrimary,
                      ),
                    ),
                    if (anime.releaseYear != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        anime.releaseYear.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: KumoriyaColors.textDisabled,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: anime.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AnimeStatus status;

  @override
  Widget build(BuildContext context) {
    final isReleasing = status == AnimeStatus.releasing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isReleasing
            ? KumoriyaColors.primary.withValues(alpha: 0.14)
            : KumoriyaColors.borderSubtle,
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
      child: Text(
        isReleasing ? 'AIRING' : 'UPCOMING',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isReleasing
              ? KumoriyaColors.primary
              : KumoriyaColors.textDisabled,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
