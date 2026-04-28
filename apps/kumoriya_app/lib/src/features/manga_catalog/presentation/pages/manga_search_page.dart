import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/theme/kumoriya_theme.dart';
import '../providers/manga_catalog_providers.dart';
import '../widgets/manga_card.dart';
import 'manga_detail_page.dart';

/// Manga universe Search: debounced search bar feeding a paginated grid.
class MangaSearchPage extends ConsumerStatefulWidget {
  const MangaSearchPage({super.key});

  @override
  ConsumerState<MangaSearchPage> createState() => _MangaSearchPageState();
}

class _MangaSearchPageState extends ConsumerState<MangaSearchPage> {
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      ref.read(mangaSearchQueryProvider.notifier).set(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(mangaSearchQueryProvider);
    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.mangaSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(child: _SearchBody(query: query)),
          ],
        ),
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (query.trim().isEmpty) {
      return _CenteredHint(
        icon: Icons.travel_explore_rounded,
        title: l10n.mangaSearchEmptyTitle,
        subtitle: l10n.mangaSearchEmptyHint,
      );
    }
    final asyncResults = ref.watch(mangaSearchProvider(query));
    return asyncResults.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _CenteredHint(
        icon: Icons.error_outline_rounded,
        title: l10n.mangaHomeError,
        subtitle: e.toString(),
      ),
      data: (results) {
        if (results.isEmpty) {
          return _CenteredHint(
            icon: Icons.search_off_rounded,
            title: l10n.mangaSearchNoResults,
            subtitle: '',
          );
        }
        return _ResultsGrid(results: results);
      },
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({required this.results});
  final List<Manga> results;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 5 : (width >= 600 ? 4 : 3);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.55,
      ),
      itemBuilder: (_, i) => MangaCard(
        manga: results[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MangaDetailPage(anilistId: results[i].anilistId),
          ),
        ),
      ),
      itemCount: results.length,
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 56, color: KumoriyaColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KumoriyaColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: KumoriyaColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
