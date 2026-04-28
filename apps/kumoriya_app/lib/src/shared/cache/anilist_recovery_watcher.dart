import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/runtime_config.dart';
import '../../features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../features/manga_catalog/presentation/providers/manga_catalog_providers.dart';
import 'anilist_health_probe.dart';
import 'combined_fallback_reason_provider.dart';
import 'fallback_reason.dart';

/// Polls the backend `/v1/anilist/health` endpoint while the combined
/// fallback signal is degraded, and invalidates the home / catalog
/// providers when AniList comes back so the user sees fresh data
/// without having to pull-to-refresh.
final anilistHealthProbeProvider = Provider<AnilistHealthProbe>((ref) {
  final probe = AnilistHealthProbe(baseUrl: KumoriyaRuntimeConfig.apiBaseUrl);
  ref.onDispose(probe.close);
  return probe;
});

/// Manually retries every catalog surface that may have been served
/// from a stale cache. Wired both from auto-recovery (background poll
/// detected AniList is back) and from the offline banner's tap-to-retry
/// gesture.
///
/// Kept in one place so both entrypoints stay in sync as we add more
/// surfaces to refresh.
void invalidateCatalogProviders(WidgetRef ref) {
  // Home shelves the user is most likely staring at when the banner
  // shows up. Other (family) providers re-run on next subscribe.
  ref.invalidate(mangaHomeProvider);
  ref.invalidate(homeCatalogProvider);
}

/// Same as [invalidateCatalogProviders] but for `Ref` (used inside
/// providers / non-widget contexts).
void invalidateCatalogProvidersFromRef(Ref ref) {
  ref.invalidate(mangaHomeProvider);
  ref.invalidate(homeCatalogProvider);
}

/// Pump-only widget. Mounts a periodic timer when the combined
/// fallback reason is anything other than [FallbackReason.none], polls
/// the backend health endpoint, and triggers provider invalidation as
/// soon as the backend reports `anilist_reachable: true`.
///
/// Renders [child] verbatim — there is no visual contribution.
class AnilistRecoveryWatcher extends ConsumerStatefulWidget {
  const AnilistRecoveryWatcher({
    super.key,
    required this.child,
    this.pollInterval = const Duration(seconds: 15),
  });

  final Widget child;
  final Duration pollInterval;

  @override
  ConsumerState<AnilistRecoveryWatcher> createState() =>
      _AnilistRecoveryWatcherState();
}

class _AnilistRecoveryWatcherState
    extends ConsumerState<AnilistRecoveryWatcher> {
  Timer? _timer;
  FallbackReason _lastReason = FallbackReason.none;

  void _onReasonChanged(FallbackReason reason) {
    if (reason == _lastReason) return;
    _lastReason = reason;
    if (reason == FallbackReason.none) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(widget.pollInterval, (_) => _probe());
    // Probe once immediately so a flap (offline → online → offline)
    // doesn't have to wait a full interval to recover.
    _probe();
  }

  Future<void> _probe() async {
    if (!mounted) return;
    final reachable = await ref
        .read(anilistHealthProbeProvider)
        .isAnilistReachable();
    if (!reachable || !mounted) return;
    developer.log(
      'AniList reachable again — invalidating catalog providers',
      name: 'AnilistRecoveryWatcher',
    );
    _timer?.cancel();
    _timer = null;
    invalidateCatalogProviders(ref);
    // The next successful fetch from each repository will reset its
    // own fallbackReason notifier to none, which collapses the banner
    // through combinedFallbackReasonProvider automatically.
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch via Consumer pattern so we react to flips synchronously.
    final notifier = ref.watch(combinedFallbackReasonProvider);
    return ValueListenableBuilder<FallbackReason>(
      valueListenable: notifier,
      builder: (context, reason, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onReasonChanged(reason);
        });
        return widget.child;
      },
    );
  }
}
