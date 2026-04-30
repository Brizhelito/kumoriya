import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_manga_plugins/kumoriya_manga_plugins.dart';

import '../../../../app/l10n.dart';
import '../../../../shared/storage_providers.dart';
import '../../../manga_catalog/presentation/providers/manga_catalog_providers.dart';

/// Advanced settings page exposing the per-plugin base URL override
/// landed in S2 (M2). One row per registered manga source plugin.
///
/// The page is intentionally minimal:
/// - Plugins are read from `mangaSourcePluginsProvider` so adding a new
///   source in S3+ surfaces it here automatically.
/// - Override values are validated as absolute http(s) URLs in both the
///   widget and the store layer (defense in depth).
/// - Saving / clearing invalidates `pluginBaseUrlOverridesProvider`,
///   which causes the source plugin provider to rebuild and the next
///   request to flow through the new mirror order.
class PluginBaseUrlOverridesPage extends ConsumerWidget {
  const PluginBaseUrlOverridesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plugins = ref.watch(mangaSourcePluginsProvider);
    final overridesAsync = ref.watch(pluginBaseUrlOverridesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPluginBaseUrlsTitle)),
      body: overridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (overrides) {
          if (plugins.isEmpty) {
            return Center(child: Text(l10n.settingsPluginBaseUrlsEmpty));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.settingsPluginBaseUrlsDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final plugin in plugins)
                _PluginOverrideCard(
                  plugin: plugin,
                  currentOverride: overrides[plugin.manifest.id],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PluginOverrideCard extends ConsumerStatefulWidget {
  const _PluginOverrideCard({
    required this.plugin,
    required this.currentOverride,
  });

  final MangaSourcePlugin plugin;
  final Uri? currentOverride;

  @override
  ConsumerState<_PluginOverrideCard> createState() =>
      _PluginOverrideCardState();
}

class _PluginOverrideCardState extends ConsumerState<_PluginOverrideCard> {
  late final TextEditingController _controller;
  String? _validationError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentOverride?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _PluginOverrideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.currentOverride?.toString() ?? '';
    if (oldWidget.currentOverride != widget.currentOverride &&
        _controller.text != current) {
      _controller.text = current;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Uri? _parseInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (!uri.isAbsolute) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final parsed = _parseInput(_controller.text);
    if (parsed == null) {
      setState(() => _validationError = l10n.settingsPluginBaseUrlsInvalid);
      return;
    }
    setState(() {
      _validationError = null;
      _busy = true;
    });
    final res = await ref
        .read(pluginBaseUrlOverrideStoreProvider)
        .set(pluginId: widget.plugin.manifest.id, baseUrl: parsed);
    if (!mounted) return;
    setState(() => _busy = false);
    res.fold(
      onFailure: (err) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.message)));
      },
      onSuccess: (_) {
        ref.invalidate(pluginBaseUrlOverridesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsPluginBaseUrlsSaved)),
        );
      },
    );
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final res = await ref
        .read(pluginBaseUrlOverrideStoreProvider)
        .clear(widget.plugin.manifest.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _controller.clear();
      _validationError = null;
    });
    res.fold(
      onFailure: (err) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err.message)));
      },
      onSuccess: (_) {
        ref.invalidate(pluginBaseUrlOverridesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsPluginBaseUrlsCleared)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final manifest = widget.plugin.manifest;
    final manifestUrls = manifest.baseUrls;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(manifest.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(manifest.id, style: theme.textTheme.bodySmall),
            if (manifestUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '${l10n.settingsPluginBaseUrlsManifestLabel}: '
                '${manifestUrls.join(", ")}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (widget.currentOverride != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '${l10n.settingsPluginBaseUrlsCurrentLabel}: ${widget.currentOverride}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.settingsPluginBaseUrlsOverrideHint,
                errorText: _validationError,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: _busy || widget.currentOverride == null
                      ? null
                      : _clear,
                  child: Text(l10n.settingsPluginBaseUrlsClear),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(l10n.settingsPluginBaseUrlsSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
