import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/icons/kumoriya_icons.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../../shared/widgets/anime_card.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/anime_catalog_providers.dart';
import 'anime_detail_page.dart';

class BrowseResultsPage extends ConsumerStatefulWidget {
  const BrowseResultsPage({super.key, this.initialGenres});

  final List<String>? initialGenres;

  @override
  ConsumerState<BrowseResultsPage> createState() => _BrowseResultsPageState();
}

class _BrowseResultsPageState extends ConsumerState<BrowseResultsPage> {
  late AnimeBrowseRequest _request;

  // Filter state
  final Set<String> _selectedGenres = <String>{};
  AnimeFormat? _selectedFormat;
  AnimeSortType _selectedSort = AnimeSortType.trending;

  List<String>? _sortedSelectedGenres() {
    if (_selectedGenres.isEmpty) return null;
    final genres = _selectedGenres.toList()..sort();
    return genres;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialGenres != null) {
      _selectedGenres.addAll(widget.initialGenres!);
    }
    _request = AnimeBrowseRequest(
      genres: _sortedSelectedGenres(),
      sort: _selectedSort,
    );
  }

  void _updateRequest() {
    setState(() {
      _request = AnimeBrowseRequest(
        genres: _sortedSelectedGenres(),
        formats: _selectedFormat != null
            ? <AnimeFormat>[_selectedFormat!]
            : null,
        sort: _selectedSort,
      );
    });
  }

  void _openDetail(int anilistId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimeDetailPage(anilistId: anilistId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final browseState = ref.watch(browseAnimeCatalogProvider(_request));
    final genres = ref.watch(genreCollectionProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        backgroundColor: KumoriyaColors.background,
        title: Text(context.l10n.browseResultsTitle),
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          // -- Filter row
          _FilterRow(
            selectedGenres: _selectedGenres,
            selectedFormat: _selectedFormat,
            selectedSort: _selectedSort,
            genres: genres,
            onGenresChanged: (g) {
              _selectedGenres
                ..clear()
                ..addAll(g);
              _updateRequest();
            },
            onFormatChanged: (f) {
              _selectedFormat = f;
              _updateRequest();
            },
            onSortChanged: (s) {
              _selectedSort = s;
              _updateRequest();
            },
            onClear: () {
              _selectedGenres.clear();
              _selectedFormat = null;
              _selectedSort = AnimeSortType.trending;
              _updateRequest();
            },
          ),
          const SizedBox(height: 8),
          // -- Results
          Expanded(
            child: _BrowseGrid(
              state: browseState,
              onOpenDetail: _openDetail,
              onRetry: () =>
                  ref.invalidate(browseAnimeCatalogProvider(_request)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedGenres,
    required this.selectedFormat,
    required this.selectedSort,
    required this.genres,
    required this.onGenresChanged,
    required this.onFormatChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  final Set<String> selectedGenres;
  final AnimeFormat? selectedFormat;
  final AnimeSortType selectedSort;
  final AsyncValue<Result<List<String>, KumoriyaError>> genres;
  final ValueChanged<Set<String>> onGenresChanged;
  final ValueChanged<AnimeFormat?> onFormatChanged;
  final ValueChanged<AnimeSortType> onSortChanged;
  final VoidCallback onClear;

  bool get _hasActiveFilter =>
      selectedGenres.isNotEmpty || selectedFormat != null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          // Genre chooser
          _FilterChip(
            label: selectedGenres.isEmpty
                ? context.l10n.browseFilterGenre
                : selectedGenres.length == 1
                ? displayGenreLabel(context, selectedGenres.first)
                : '${context.l10n.browseFilterGenre} (${selectedGenres.length})',
            active: selectedGenres.isNotEmpty,
            onTap: () => _showGenrePicker(context),
          ),
          const SizedBox(width: 8),
          // Format chooser
          _FilterChip(
            label: selectedFormat != null
                ? _formatLabel(context, selectedFormat!)
                : context.l10n.browseFilterFormat,
            active: selectedFormat != null,
            onTap: () => _showFormatPicker(context),
          ),
          const SizedBox(width: 8),
          // Sort chooser
          _FilterChip(
            label: _sortLabel(context, selectedSort),
            active: true,
            icon: Icons.sort_rounded,
            onTap: () => _showSortPicker(context),
          ),
          if (_hasActiveFilter) ...<Widget>[
            const SizedBox(width: 8),
            ActionChip(
              label: Text(context.l10n.browseFilterClear),
              onPressed: onClear,
              avatar: const Icon(KumoriyaIcons.close, size: 16),
              backgroundColor: KumoriyaColors.surface,
              labelStyle: const TextStyle(
                color: KumoriyaColors.textMuted,
                fontSize: 13,
              ),
              side: const BorderSide(color: KumoriyaColors.borderSubtle),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KumoriyaRadius.full),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showGenrePicker(BuildContext context) {
    final genreResult = genres.value;
    if (genreResult == null) return;
    final genreList = genreResult.fold(
      onFailure: (_) => <String>[],
      onSuccess: (list) => list,
    );
    if (genreList.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KumoriyaRadius.xl),
        ),
      ),
      builder: (ctx) => _MultiGenrePickerSheet(
        title: context.l10n.browseFilterGenre,
        genres: genreList,
        selected: selectedGenres,
        onDone: (result) {
          Navigator.pop(ctx);
          onGenresChanged(result);
        },
        onClear: () {
          Navigator.pop(ctx);
          onGenresChanged(<String>{});
        },
      ),
    );
  }

  void _showFormatPicker(BuildContext context) {
    final formats = <AnimeFormat>[
      AnimeFormat.tv,
      AnimeFormat.movie,
      AnimeFormat.ova,
      AnimeFormat.ona,
      AnimeFormat.special,
    ];

    showModalBottomSheet<AnimeFormat>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KumoriyaRadius.xl),
        ),
      ),
      builder: (ctx) => _PickerSheet(
        title: context.l10n.browseFilterFormat,
        items: formats.map((f) => _formatLabel(context, f)).toList(),
        selected: selectedFormat != null
            ? _formatLabel(context, selectedFormat!)
            : null,
        onSelected: (label) {
          Navigator.pop(ctx);
          final idx = formats.indexWhere(
            (f) => _formatLabel(context, f) == label,
          );
          if (idx != -1) onFormatChanged(formats[idx]);
        },
        onClear: () {
          Navigator.pop(ctx);
          onFormatChanged(null);
        },
      ),
    );
  }

  void _showSortPicker(BuildContext context) {
    final sortTypes = AnimeSortType.values;

    showModalBottomSheet<AnimeSortType>(
      context: context,
      backgroundColor: KumoriyaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KumoriyaRadius.xl),
        ),
      ),
      builder: (ctx) => _PickerSheet(
        title: context.l10n.browseFilterSort,
        items: sortTypes.map((s) => _sortLabel(context, s)).toList(),
        selected: _sortLabel(context, selectedSort),
        onSelected: (label) {
          Navigator.pop(ctx);
          final idx = sortTypes.indexWhere(
            (s) => _sortLabel(context, s) == label,
          );
          if (idx != -1) onSortChanged(sortTypes[idx]);
        },
      ),
    );
  }

  static String _formatLabel(BuildContext context, AnimeFormat format) {
    return switch (format) {
      AnimeFormat.tv => context.l10n.formatTv,
      AnimeFormat.movie => context.l10n.formatMovie,
      AnimeFormat.ova => context.l10n.formatOva,
      AnimeFormat.ona => context.l10n.formatOna,
      AnimeFormat.special => context.l10n.formatSpecial,
      AnimeFormat.unknown => '?',
    };
  }

  static String _sortLabel(BuildContext context, AnimeSortType sort) {
    return switch (sort) {
      AnimeSortType.trending => context.l10n.browseSortTrending,
      AnimeSortType.score => context.l10n.browseSortScore,
      AnimeSortType.popularity => context.l10n.browseSortPopularity,
      AnimeSortType.favourites => context.l10n.browseSortFavourites,
      AnimeSortType.startDate => context.l10n.browseSortNewest,
      AnimeSortType.titleRomaji => context.l10n.browseSortTitle,
    };
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: 16) : null,
      onPressed: onTap,
      backgroundColor: active
          ? KumoriyaColors.primaryContainer
          : KumoriyaColors.surface,
      labelStyle: TextStyle(
        color: active ? KumoriyaColors.primaryLight : KumoriyaColors.textMuted,
        fontSize: 13,
      ),
      side: BorderSide(
        color: active
            ? KumoriyaColors.primary.withValues(alpha: 0.5)
            : KumoriyaColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KumoriyaRadius.full),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker bottom sheet
// ---------------------------------------------------------------------------

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.onSelected,
    this.selected,
    this.onClear,
  });

  final String title;
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: KumoriyaColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: Text(context.l10n.browseFilterClear),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item == selected;
                return ListTile(
                  title: Text(
                    item,
                    style: TextStyle(
                      color: isSelected
                          ? KumoriyaColors.primaryLight
                          : KumoriyaColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: KumoriyaColors.primaryLight,
                          size: 20,
                        )
                      : null,
                  onTap: () => onSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-genre picker bottom sheet
// ---------------------------------------------------------------------------

class _MultiGenrePickerSheet extends StatefulWidget {
  const _MultiGenrePickerSheet({
    required this.title,
    required this.genres,
    required this.selected,
    required this.onDone,
    required this.onClear,
  });

  final String title;
  final List<String> genres;
  final Set<String> selected;
  final ValueChanged<Set<String>> onDone;
  final VoidCallback onClear;

  @override
  State<_MultiGenrePickerSheet> createState() => _MultiGenrePickerSheetState();
}

class _MultiGenrePickerSheetState extends State<_MultiGenrePickerSheet> {
  late final Set<String> _draft = <String>{...widget.selected};

  void _toggle(String genre) {
    setState(() {
      if (_draft.contains(genre)) {
        _draft.remove(genre);
      } else {
        _draft.add(genre);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: KumoriyaColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_draft.isNotEmpty)
                      TextButton(
                        onPressed: widget.onClear,
                        child: Text(context.l10n.browseFilterClear),
                      ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () => widget.onDone(_draft),
                      style: FilledButton.styleFrom(
                        backgroundColor: KumoriyaColors.primary,
                        minimumSize: const Size(64, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KumoriyaRadius.md,
                          ),
                        ),
                      ),
                      child: Text(
                        _draft.isEmpty
                            ? context.l10n.browseFilterApply
                            : context.l10n.browseGenreApply(_draft.length),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // -- Selected chips summary
          if (_draft.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _draft.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final genre = _draft.elementAt(index);
                    return Chip(
                      label: Text(displayGenreLabel(context, genre)),
                      deleteIcon: const Icon(KumoriyaIcons.close, size: 14),
                      onDeleted: () => _toggle(genre),
                      backgroundColor: KumoriyaColors.primaryContainer,
                      labelStyle: const TextStyle(
                        color: KumoriyaColors.primaryLight,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: KumoriyaColors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          KumoriyaRadius.full,
                        ),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ),
          // -- Genre list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.genres.length,
              itemBuilder: (context, index) {
                final genre = widget.genres[index];
                final isSelected = _draft.contains(genre);
                return ListTile(
                  title: Text(
                    displayGenreLabel(context, genre),
                    style: TextStyle(
                      color: isSelected
                          ? KumoriyaColors.primaryLight
                          : KumoriyaColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: KumoriyaColors.primaryLight,
                          size: 20,
                        )
                      : null,
                  onTap: () => _toggle(genre),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse results grid
// ---------------------------------------------------------------------------

class _BrowseGrid extends StatelessWidget {
  const _BrowseGrid({
    required this.state,
    required this.onOpenDetail,
    required this.onRetry,
  });

  final AsyncValue<Result<List<Anime>, KumoriyaError>> state;
  final ValueChanged<int> onOpenDetail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => LoadingStateView(label: context.l10n.searchLoading),
      error: (_, _) => ErrorStateView(
        message: context.l10n.genericLoadFailure,
        onRetry: onRetry,
      ),
      data: (result) => result.fold(
        onFailure: (error) => ErrorStateView(
          message: mapErrorMessage(context, error),
          onRetry: onRetry,
        ),
        onSuccess: (animeList) {
          if (animeList.isEmpty) {
            return EmptyStateView(
              icon: Icons.filter_list_off_rounded,
              message: context.l10n.browseNoResults,
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.52,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: animeList.length,
            itemBuilder: (context, index) {
              final anime = animeList[index];
              return AnimeCard(
                anime: anime,
                onTap: () => onOpenDetail(anime.anilistId),
              );
            },
          );
        },
      ),
    );
  }
}
