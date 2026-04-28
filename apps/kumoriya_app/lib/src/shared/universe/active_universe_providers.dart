import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import 'active_universe_store.dart';

/// Singleton provider for the on-disk universe store.
///
/// Tests override this with an in-memory implementation.
final activeUniverseStoreProvider = Provider<ActiveUniverseStore>((ref) {
  return const ActiveUniverseStore();
});

/// Active media universe (`anime` by default). Boots from the on-disk
/// store; defaults to [MediaKind.anime] while the load is pending or if
/// the file is missing/corrupt. Every set is persisted best-effort.
final activeUniverseProvider =
    NotifierProvider<ActiveUniverseNotifier, MediaKind>(
      ActiveUniverseNotifier.new,
    );

class ActiveUniverseNotifier extends Notifier<MediaKind> {
  @override
  MediaKind build() {
    // Default to anime so the UI never blocks on a disk read. The
    // background load below upgrades the value once available.
    Future<void>.microtask(_loadFromDisk);
    return MediaKind.anime;
  }

  Future<void> _loadFromDisk() async {
    final store = ref.read(activeUniverseStoreProvider);
    final loaded = await store.read();
    if (loaded != null && loaded != state) {
      state = loaded;
    }
  }

  /// Sets the active universe and persists the change. Persistence is
  /// fire-and-forget: failures are silent so the UI never blocks.
  void set(MediaKind kind) {
    if (kind == state) return;
    state = kind;
    final store = ref.read(activeUniverseStoreProvider);
    // ignore: discarded_futures
    store.write(kind);
  }

  /// Convenience toggle. Used by the segmented switch.
  void toggle() {
    set(state == MediaKind.anime ? MediaKind.manga : MediaKind.anime);
  }
}
