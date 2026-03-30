import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../application/models/seasonal_discovery_catalog.dart';
import '../providers/anime_catalog_providers.dart';
import '../support/season_presentation.dart';
import '../widgets/anime_list_tile.dart';
import 'anime_detail_page.dart';

class SeasonHubPage extends ConsumerStatefulWidget {
  const SeasonHubPage({super.key});

  @override
  ConsumerState<SeasonHubPage> createState() => _SeasonHubPageState();
}

class _SeasonHubPageState extends ConsumerState<SeasonHubPage> {
  late SeasonalCatalogRequest _request;

  @override
  void initState() {
    super.initState();
    _request = currentSeasonalCatalogRequest();
  }

  @override
  Widget build(BuildContext context) {
    final discoveryAsync = ref.watch(
      seasonalDiscoveryCatalogProvider(_request),
    );

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: KumoriyaColors.textPrimary,
        title: Text(context.l10n.seasonHubTitle),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: _SeasonSelector(
                request: _request,
                onChanged: (next) => setState(() => _request = next),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _SeasonChips(
                request: _request,
                onChanged: (next) => setState(() => _request = next),
              ),
            ),
            Expanded(
              child: discoveryAsync.when(
                loading: () =>
                    LoadingStateView(label: context.l10n.seasonHubLoading),
                error: (_, _) => ErrorStateView(
                  message: context.l10n.genericLoadFailure,
                  onRetry: () => ref.invalidate(
                    seasonalDiscoveryCatalogProvider(_request),
                  ),
                ),
                data: (result) => result.fold(
                  onFailure: (error) => ErrorStateView(
                    message: mapErrorMessage(context, error),
                    onRetry: () => ref.invalidate(
                      seasonalDiscoveryCatalogProvider(_request),
                    ),
                  ),
                  onSuccess: (catalog) => _SeasonHubBody(catalog: catalog),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  const _SeasonSelector({required this.request, required this.onChanged});

  final SeasonalCatalogRequest request;
  final ValueChanged<SeasonalCatalogRequest> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => onChanged(shiftSeason(request, -1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            displaySeasonYearLabel(context, request.season, request.year),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(shiftSeason(request, 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({required this.request, required this.onChanged});

  final SeasonalCatalogRequest request;
  final ValueChanged<SeasonalCatalogRequest> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AnimeSeason.values
          .map((season) {
            final selected = season == request.season;
            return ChoiceChip(
              label: Text(displaySeasonLabel(context, season)),
              selected: selected,
              onSelected: (_) {
                onChanged(
                  SeasonalCatalogRequest(
                    season: season,
                    year: request.year,
                    page: request.page,
                    perPage: request.perPage,
                    includeCarryovers: request.includeCarryovers,
                  ),
                );
              },
            );
          })
          .toList(growable: false),
    );
  }
}

class _SeasonHubBody extends StatelessWidget {
  const _SeasonHubBody({required this.catalog});

  final SeasonalDiscoveryCatalog catalog;

  void _openDetail(BuildContext context, Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: anime.anilistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Tab>[
                Tab(text: context.l10n.seasonHubInSeasonSection),
                Tab(text: context.l10n.seasonHubUpcomingSection),
                Tab(text: context.l10n.seasonHubRecommendedSection),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _SeasonListSection(
                  emptyMessage: context.l10n.seasonHubInSeasonEmpty,
                  items: catalog.inSeason,
                  onTap: (anime) => _openDetail(context, anime),
                ),
                _SeasonListSection(
                  emptyMessage: context.l10n.seasonHubUpcomingEmpty,
                  items: catalog.upcoming,
                  onTap: (anime) => _openDetail(context, anime),
                ),
                _SeasonListSection(
                  emptyMessage: context.l10n.seasonHubRecommendedEmpty,
                  items: catalog.recommended,
                  onTap: (anime) => _openDetail(context, anime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonListSection extends StatelessWidget {
  const _SeasonListSection({
    required this.emptyMessage,
    required this.items,
    required this.onTap,
  });

  final String emptyMessage;
  final List<Anime> items;
  final ValueChanged<Anime> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: EmptyStateView(message: emptyMessage),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final anime = items[index];
        return AnimeListTile(anime: anime, onTap: () => onTap(anime));
      },
    );
  }
}
