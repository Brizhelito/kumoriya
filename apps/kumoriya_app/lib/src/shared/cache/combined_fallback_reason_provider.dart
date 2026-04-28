import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import '../../features/manga_catalog/presentation/providers/manga_catalog_providers.dart';
import 'fallback_reason.dart';

/// Combines the anime and manga fallback notifiers into a single
/// `ValueNotifier<FallbackReason>` so the navigation shell shows one
/// banner regardless of which universe the user is browsing.
///
/// Severity order: `anilistDown` > `offline` > `none`. Whichever side
/// reports the most degraded state wins.
final combinedFallbackReasonProvider =
    Provider.autoDispose<ValueNotifier<FallbackReason>>((ref) {
      final anime = ref.watch(anilistCacheFallbackReasonProvider);
      final manga = ref.watch(mangaCacheFallbackReasonProvider);
      final combined = ValueNotifier<FallbackReason>(
        _merge(anime.value, manga.value),
      );

      void update() {
        combined.value = _merge(anime.value, manga.value);
      }

      anime.addListener(update);
      manga.addListener(update);
      ref.onDispose(() {
        anime.removeListener(update);
        manga.removeListener(update);
        combined.dispose();
      });

      return combined;
    });

FallbackReason _merge(FallbackReason a, FallbackReason b) {
  // anilistDown is the most severe — upstream is broken regardless of
  // local connectivity.
  if (a == FallbackReason.anilistDown || b == FallbackReason.anilistDown) {
    return FallbackReason.anilistDown;
  }
  if (a == FallbackReason.offline || b == FallbackReason.offline) {
    return FallbackReason.offline;
  }
  return FallbackReason.none;
}
