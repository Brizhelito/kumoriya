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

class TagGuidedFindPage extends ConsumerStatefulWidget {
  const TagGuidedFindPage({super.key});

  @override
  ConsumerState<TagGuidedFindPage> createState() => _TagGuidedFindPageState();
}

class _TagGuidedFindPageState extends ConsumerState<TagGuidedFindPage> {
  final Set<String> _selectedTags = <String>{};
  String? _expandedCategory;
  String _tagFilter = '';
  bool _showResults = false;

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
      _showResults = false;
    });
  }

  void _findAnime() {
    if (_selectedTags.isEmpty) return;
    setState(() => _showResults = true);
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
    final tagsState = ref.watch(tagCollectionProvider);

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      appBar: AppBar(
        backgroundColor: KumoriyaColors.background,
        title: Text(context.l10n.tagSearchTitle),
        elevation: 0,
      ),
      body: _showResults
          ? _TagResults(
              tags: _selectedTags.toList(),
              onOpenDetail: _openDetail,
              onBack: () => setState(() => _showResults = false),
            )
          : _TagSelector(
              tagsState: tagsState,
              selectedTags: _selectedTags,
              expandedCategory: _expandedCategory,
              tagFilter: _tagFilter,
              onToggleTag: _toggleTag,
              onExpandCategory: (cat) {
                setState(() {
                  _expandedCategory = _expandedCategory == cat ? null : cat;
                });
              },
              onFilterChanged: (v) => setState(() => _tagFilter = v),
              onFindAnime: _findAnime,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag selector
// ---------------------------------------------------------------------------

class _TagSelector extends StatelessWidget {
  const _TagSelector({
    required this.tagsState,
    required this.selectedTags,
    required this.expandedCategory,
    required this.tagFilter,
    required this.onToggleTag,
    required this.onExpandCategory,
    required this.onFilterChanged,
    required this.onFindAnime,
  });

  final AsyncValue<Result<List<AnimeTag>, KumoriyaError>> tagsState;
  final Set<String> selectedTags;
  final String? expandedCategory;
  final String tagFilter;
  final ValueChanged<String> onToggleTag;
  final ValueChanged<String> onExpandCategory;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onFindAnime;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // -- Header + subtitle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.tagSearchSubtitle,
                style: const TextStyle(
                  color: KumoriyaColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              // -- Step-by-step guide
              if (selectedTags.isEmpty) ...<Widget>[
                _TagSearchGuide(),
                const SizedBox(height: 12),
              ],
              // -- Tag filter text field
              SizedBox(
                height: 40,
                child: TextField(
                  onChanged: onFilterChanged,
                  style: const TextStyle(
                    fontSize: 14,
                    color: KumoriyaColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      KumoriyaIcons.search,
                      size: 18,
                      color: KumoriyaColors.navInactive,
                    ),
                    hintText: context.l10n.tagSearchFilterHint,
                    hintStyle: const TextStyle(
                      color: KumoriyaColors.textDisabled,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: KumoriyaColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        // -- Selected tags
        if (selectedTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: selectedTags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = selectedTags.elementAt(index);
                return Chip(
                  label: Text(displayTagLabel(context, tag)),
                  deleteIcon: const Icon(KumoriyaIcons.close, size: 14),
                  onDeleted: () => onToggleTag(tag),
                  backgroundColor: KumoriyaColors.primaryContainer,
                  labelStyle: const TextStyle(
                    color: KumoriyaColors.primaryLight,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: KumoriyaColors.primary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        // -- Tag categories
        Expanded(
          child: tagsState.when(
            loading: () => LoadingStateView(label: context.l10n.searchLoading),
            error: (_, _) =>
                ErrorStateView(message: context.l10n.genericLoadFailure),
            data: (result) => result.fold(
              onFailure: (_) =>
                  ErrorStateView(message: context.l10n.genericLoadFailure),
              onSuccess: (tags) => _TagCategoryList(
                tags: tags,
                selectedTags: selectedTags,
                expandedCategory: expandedCategory,
                tagFilter: tagFilter,
                onToggleTag: onToggleTag,
                onExpandCategory: onExpandCategory,
              ),
            ),
          ),
        ),
        // -- Find button
        if (selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onFindAnime,
                icon: const Icon(KumoriyaIcons.search, size: 18),
                label: Text(
                  '${context.l10n.tagSearchFindAnime} (${selectedTags.length})',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: KumoriyaColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tag category list
// ---------------------------------------------------------------------------

class _TagCategoryList extends StatelessWidget {
  const _TagCategoryList({
    required this.tags,
    required this.selectedTags,
    required this.expandedCategory,
    required this.tagFilter,
    required this.onToggleTag,
    required this.onExpandCategory,
  });

  final List<AnimeTag> tags;
  final Set<String> selectedTags;
  final String? expandedCategory;
  final String tagFilter;
  final ValueChanged<String> onToggleTag;
  final ValueChanged<String> onExpandCategory;

  @override
  Widget build(BuildContext context) {
    final normalizedFilter = tagFilter.trim().toLowerCase();

    // Group by category
    final Map<String, List<AnimeTag>> grouped = <String, List<AnimeTag>>{};
    for (final tag in tags) {
      final category = tag.category ?? 'Other';
      final localizedTagName = displayTagLabel(context, tag.name).toLowerCase();

      // Match against both the raw AniList tag and the translated label.
      if (normalizedFilter.isNotEmpty &&
          !tag.name.toLowerCase().contains(normalizedFilter) &&
          !localizedTagName.contains(normalizedFilter)) {
        continue;
      }
      grouped.putIfAbsent(category, () => <AnimeTag>[]).add(tag);
    }

    final categories = grouped.keys.toList()
      ..sort(
        (a, b) => displayTagCategoryLabel(
          context,
          a,
        ).compareTo(displayTagCategoryLabel(context, b)),
      );

    if (categories.isEmpty) {
      return Center(
        child: Text(
          context.l10n.tagSearchNoTags,
          style: const TextStyle(color: KumoriyaColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryTags = grouped[category]!;
        final isExpanded = expandedCategory == category;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () => onExpandCategory(category),
              borderRadius: BorderRadius.circular(KumoriyaRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        displayTagCategoryLabel(context, category),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: KumoriyaColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${categoryTags.length}',
                      style: const TextStyle(
                        color: KumoriyaColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: KumoriyaColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryTags
                      .map((tag) {
                        final selected = selectedTags.contains(tag.name);
                        return FilterChip(
                          label: Text(displayTagLabel(context, tag.name)),
                          selected: selected,
                          onSelected: (_) => onToggleTag(tag.name),
                          selectedColor: KumoriyaColors.primaryContainer,
                          backgroundColor: KumoriyaColors.surface,
                          checkmarkColor: KumoriyaColors.primaryLight,
                          labelStyle: TextStyle(
                            color: selected
                                ? KumoriyaColors.primaryLight
                                : KumoriyaColors.textSecondary,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected
                                ? KumoriyaColors.primary.withValues(alpha: 0.5)
                                : KumoriyaColors.borderSubtle,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              KumoriyaRadius.full,
                            ),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            Divider(color: KumoriyaColors.borderSubtle, height: 1),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Step-by-step guide
// ---------------------------------------------------------------------------

class _TagSearchGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KumoriyaColors.surface,
        borderRadius: BorderRadius.circular(KumoriyaRadius.md),
        border: Border.all(color: KumoriyaColors.borderSubtle),
      ),
      child: Column(
        children: <Widget>[
          _GuideStep(
            number: '1',
            text: context.l10n.tagSearchGuideStep1,
            icon: Icons.folder_open_rounded,
          ),
          const SizedBox(height: 8),
          _GuideStep(
            number: '2',
            text: context.l10n.tagSearchGuideStep2,
            icon: Icons.touch_app_rounded,
          ),
          const SizedBox(height: 8),
          _GuideStep(
            number: '3',
            text: context.l10n.tagSearchGuideStep3,
            icon: Icons.search_rounded,
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.text,
    required this.icon,
  });

  final String number;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: KumoriyaColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: KumoriyaColors.primaryLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: KumoriyaColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: KumoriyaColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tag results (after pressing "Find anime")
// ---------------------------------------------------------------------------

class _TagResults extends ConsumerWidget {
  const _TagResults({
    required this.tags,
    required this.onOpenDetail,
    required this.onBack,
  });

  final List<String> tags;
  final ValueChanged<int> onOpenDetail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = AnimeBrowseRequest(tags: tags, sort: AnimeSortType.score);
    final state = ref.watch(browseAnimeCatalogProvider(request));

    return Column(
      children: <Widget>[
        // -- Selected tags summary
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: KumoriyaColors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.tagSearchSelectedTags(tags.length),
                  style: const TextStyle(
                    color: KumoriyaColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        // -- Tag chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tags.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Chip(
                label: Text(tags[index]),
                backgroundColor: KumoriyaColors.primaryContainer,
                labelStyle: const TextStyle(
                  color: KumoriyaColors.primaryLight,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: KumoriyaColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KumoriyaRadius.full),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // -- Results grid
        Expanded(
          child: state.when(
            loading: () => LoadingStateView(label: context.l10n.searchLoading),
            error: (_, _) => ErrorStateView(
              message: context.l10n.genericLoadFailure,
              onRetry: () =>
                  ref.invalidate(browseAnimeCatalogProvider(request)),
            ),
            data: (result) => result.fold(
              onFailure: (error) => ErrorStateView(
                message: mapErrorMessage(context, error),
                onRetry: () =>
                    ref.invalidate(browseAnimeCatalogProvider(request)),
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
          ),
        ),
      ],
    );
  }
}
