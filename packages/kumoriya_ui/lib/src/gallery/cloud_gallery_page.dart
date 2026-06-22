import 'package:flutter/material.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../components/continue_watching_card.dart';
import '../components/download_row.dart';
import '../components/episode_row.dart';
import '../components/meta_chip.dart';
import '../components/poster_card.dart';
import '../components/section_header.dart';
import '../components/source_badge.dart';
import '../components/state_views.dart';
import '../components/status_pill.dart';
import '../platform/form_factor_provider.dart';
import '../primitives/cloud_badge.dart';
import '../primitives/cloud_button.dart';
import '../primitives/cloud_card.dart';
import '../primitives/cloud_chip.dart';
import '../primitives/cloud_divider.dart';
import '../primitives/cloud_progress.dart';
import '../primitives/cloud_search_bar.dart';
import '../primitives/cloud_tooltip.dart';
import '../tokens/cloud_colors.dart';
import '../tokens/cloud_spacing.dart';

/// Dev-only gallery that renders every cloud component in every state.
///
/// Access via `kumoriya://gallery` deep link or Settings → "UI Gallery (Dev)".
/// Only available in debug mode.
class CloudGalleryPage extends StatefulWidget {
  const CloudGalleryPage({super.key});

  @override
  State<CloudGalleryPage> createState() => _CloudGalleryPageState();
}

class _CloudGalleryPageState extends State<CloudGalleryPage> {
  bool _isDark = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _isDark ? CloudColors.noche() : CloudColors.nublado();

    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: colors.bg,
        colorScheme: ColorScheme(
          brightness: _isDark ? Brightness.dark : Brightness.light,
          primary: colors.primary,
          onPrimary: colors.bg,
          secondary: colors.accent,
          onSecondary: colors.text,
          error: colors.error,
          onError: colors.bg,
          surface: colors.surface,
          onSurface: colors.text,
        ),
      ),
      child: FormFactorProvider(
        colors: colors,
        child: Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            title: const Text('Cloud UI Gallery'),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() => _isDark = !_isDark),
                child: Text(
                  _isDark ? 'Nublado' : 'Noche',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.all(CloudSpacing.s4),
            children: <Widget>[
              _buildSection('Colors', _buildColorSwatches(colors)),
              _buildSection('Buttons', _buildButtons()),
              _buildSection('Chips', _buildChips()),
              _buildSection('Search Bar', _buildSearchBar()),
              _buildSection('Progress', _buildProgress()),
              _buildSection('Dividers', const CloudDivider()),
              _buildSection('Badges', _buildBadges()),
              _buildSection('Cards', _buildCards()),
              _buildSection('Posters', _buildPosters()),
              _buildSection('Continue Watching', _buildContinueWatching()),
              _buildSection('Episode Rows', _buildEpisodeRows()),
              _buildSection('State Views', _buildStateViews()),
              _buildSection('Status Pills', _buildStatusPills()),
              _buildSection('Source Badges', _buildSourceBadges()),
              _buildSection('Meta Chips', _buildMetaChips()),
              _buildSection('Download Rows', _buildDownloadRows()),
              _buildSection('Tooltips (Desktop)', _buildTooltips()),
              SizedBox(height: CloudSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    final colors = FormFactorProvider.colorsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: CloudSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: CloudSpacing.s3),
          content,
        ],
      ),
    );
  }

  Widget _buildColorSwatches(CloudColors colors) {
    final swatches = <MapEntry<String, Color>>[
      MapEntry('bg', colors.bg),
      MapEntry('bgElev', colors.bgElev),
      MapEntry('surface', colors.surface),
      MapEntry('surface2', colors.surface2),
      MapEntry('mist', colors.mist),
      MapEntry('text', colors.text),
      MapEntry('textMuted', colors.textMuted),
      MapEntry('textSoft', colors.textSoft),
      MapEntry('primary', colors.primary),
      MapEntry('primarySoft', colors.primarySoft),
      MapEntry('accent', colors.accent),
      MapEntry('accentSoft', colors.accentSoft),
      MapEntry('success', colors.success),
      MapEntry('warning', colors.warning),
      MapEntry('error', colors.error),
      MapEntry('star', colors.star),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final entry in swatches)
          _ColorSwatch(name: entry.key, color: entry.value),
      ],
    );
  }

  Widget _buildButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        CloudButton.primary(onPressed: () {}, label: 'Primary'),
        CloudButton.secondary(onPressed: () {}, label: 'Secondary'),
        CloudButton.ghost(onPressed: () {}, label: 'Ghost'),
        CloudButton.primary(onPressed: null, label: 'Disabled'),
        CloudButton.primary(
          onPressed: () {},
          label: 'With Icon',
          icon: Icons.play_arrow_rounded,
        ),
      ],
    );
  }

  Widget _buildChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        CloudChip(label: 'Tag', variant: CloudChipVariant.tag),
        CloudChip(label: 'Airing', variant: CloudChipVariant.airing),
        CloudChip(label: 'Finished', variant: CloudChipVariant.finished),
        CloudChip(label: 'Upcoming', variant: CloudChipVariant.upcoming),
        CloudChip(
          label: '9.1',
          variant: CloudChipVariant.rating,
          icon: Icons.star_rounded,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return CloudSearchBar(
      controller: _searchController,
      hintText: 'Search anime, manga…',
    );
  }

  Widget _buildProgress() {
    return Column(
      children: <Widget>[
        CloudProgress(value: 0.3),
        SizedBox(height: CloudSpacing.s3),
        CloudProgress(value: 0.7),
        SizedBox(height: CloudSpacing.s3),
        CloudProgress(value: 1.0),
      ],
    );
  }

  Widget _buildBadges() {
    return Wrap(
      spacing: 12,
      children: <Widget>[
        CloudBadge(label: 'NEW'),
        CloudBadge(label: 'EP 12'),
        CloudBadge(label: 'HOT', icon: Icons.local_fire_department_rounded),
      ],
    );
  }

  Widget _buildCards() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: <Widget>[
        SizedBox(
          width: 200,
          child: CloudCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Cloud Card',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('Default card with gradient background and cloud shadow.'),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: CloudCard(
            gradient: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Flat Card',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('No gradient, solid surface background.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosters() {
    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: 160,
          child: PosterCard(
            imageUrl: '',
            title: ['Frieren', 'Mushishi', 'Vinland Saga', 'Odd Taxi'][i],
            subtitle: ['2024', '2005', '2021', '2021'][i],
            badge: i == 0 ? 'NEW' : null,
            onTap: () {},
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatching() {
    return SizedBox(
      height: 200,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          ContinueWatchingCard(
            animeTitle: 'Frieren: Beyond Journey\'s End',
            episodeLabel: 'Episode 12',
            progress: 0.65,
            onResume: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRows() {
    return Column(
      children: <Widget>[
        EpisodeRow(
          episodeNumber: '1',
          title: 'The Journey Begins',
          subtitle: '24 min · Source A',
          state: EpisodeRowState.defaultState,
          onTap: () {},
        ),
        SizedBox(height: 8),
        EpisodeRow(
          episodeNumber: '12',
          title: 'The Final Battle',
          subtitle: '24 min · Source A',
          state: EpisodeRowState.active,
          onTap: () {},
        ),
        SizedBox(height: 8),
        EpisodeRow(
          episodeNumber: '5',
          title: 'A Quiet Moment',
          state: EpisodeRowState.watched,
        ),
        SizedBox(height: 8),
        EpisodeRow(
          episodeNumber: '13',
          title: 'Not Yet Aired',
          state: EpisodeRowState.notPlayable,
        ),
        SizedBox(height: 8),
        EpisodeRow(
          episodeNumber: '3',
          title: 'Downloaded Episode',
          state: EpisodeRowState.downloaded,
          onTap: () {},
        ),
        SizedBox(height: 8),
        EpisodeRow(
          episodeNumber: '7',
          title: 'With Progress',
          progress: 0.4,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildStateViews() {
    return Column(
      children: <Widget>[
        SizedBox(height: 120, child: CloudLoadingView(label: 'Loading anime…')),
        SizedBox(height: CloudSpacing.s4),
        CloudEmptyView(
          icon: Icons.bookmarks_outlined,
          title: 'Your library is empty',
          message: 'Add anime to your list to see them here.',
          actionLabel: 'Browse anime',
          onAction: () {},
        ),
        SizedBox(height: CloudSpacing.s4),
        CloudErrorView(
          message: 'Could not load anime. Check your connection.',
          onRetry: () {},
        ),
      ],
    );
  }

  Widget _buildStatusPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        StatusPill(status: AnimeStatus.releasing),
        StatusPill(status: AnimeStatus.finished),
        StatusPill(status: AnimeStatus.notYetReleased),
        StatusPill(status: AnimeStatus.cancelled),
        StatusPill(status: AnimeStatus.hiatus),
      ],
    );
  }

  Widget _buildSourceBadges() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        SourceBadge(sourceName: 'JKAnime'),
        SourceBadge(sourceName: 'AnimeFLV'),
        SourceBadge(sourceName: 'AnimeNexus', isHighlighted: true),
      ],
    );
  }

  Widget _buildMetaChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        MetaChip(label: 'TV'),
        MetaChip(label: '2024'),
        MetaChip(label: '24 eps'),
        MetaChip(label: 'Shounen', isActive: true),
      ],
    );
  }

  Widget _buildDownloadRows() {
    return Column(
      children: <Widget>[
        DownloadRow(
          animeTitle: 'Frieren',
          episodeLabel: 'Episode 5',
          status: DownloadStatus.downloading,
          progress: 0.45,
        ),
        SizedBox(height: 8),
        DownloadRow(
          animeTitle: 'Mushishi',
          episodeLabel: 'Episode 12',
          status: DownloadStatus.completed,
        ),
        SizedBox(height: 8),
        DownloadRow(
          animeTitle: 'Odd Taxi',
          episodeLabel: 'Episode 3',
          status: DownloadStatus.paused,
          progress: 0.2,
        ),
      ],
    );
  }

  Widget _buildTooltips() {
    return Wrap(
      spacing: 16,
      children: <Widget>[
        CloudTooltip(
          message: 'This is a tooltip',
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FormFactorProvider.colorsOf(context).surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Hover me (desktop)'),
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
        ),
        SizedBox(height: 4),
        Text(name, style: TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
