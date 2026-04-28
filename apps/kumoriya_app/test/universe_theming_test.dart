import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/theme/kumoriya_theme.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_providers.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_store.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

class _InMemoryUniverseStore implements ActiveUniverseStore {
  MediaKind? _value;

  @override
  Future<MediaKind?> read() async => _value;

  @override
  Future<void> write(MediaKind kind) async {
    _value = kind;
  }
}

class _PreloadedUniverseNotifier extends ActiveUniverseNotifier {
  _PreloadedUniverseNotifier(this._initial);
  final MediaKind _initial;

  @override
  MediaKind build() => _initial;
}

/// A self-contained app whose theme is driven by `universeAccentProvider`,
/// matching `KumoriyaApp` wiring. Captures the active `BuildContext` so
/// tests can read `Theme.of(context)` without spinning up the real shell.
Widget _buildThemedApp({required MediaKind initial, required Widget child}) {
  return ProviderScope(
    overrides: [
      activeUniverseStoreProvider.overrideWithValue(_InMemoryUniverseStore()),
      activeUniverseProvider.overrideWith(
        () => _PreloadedUniverseNotifier(initial),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final accent = ref.watch(universeAccentProvider);
        return MaterialApp(
          theme: KumoriyaTheme.forUniverse(accent),
          home: Scaffold(body: child),
        );
      },
    ),
  );
}

void main() {
  group('Slice 7.5 — Wave A: shell/nav theme primary', () {
    testWidgets('anime universe resolves colorScheme.primary to anime hue', (
      tester,
    ) async {
      late Color resolved;
      await tester.pumpWidget(
        _buildThemedApp(
          initial: MediaKind.anime,
          child: Builder(
            builder: (ctx) {
              resolved = Theme.of(ctx).colorScheme.primary;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, KumoriyaColors.primaryAnime);
    });

    testWidgets('manga universe resolves colorScheme.primary to manga hue', (
      tester,
    ) async {
      late Color resolved;
      await tester.pumpWidget(
        _buildThemedApp(
          initial: MediaKind.manga,
          child: Builder(
            builder: (ctx) {
              resolved = Theme.of(ctx).colorScheme.primary;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, KumoriyaColors.primaryManga);
    });

    testWidgets('flipping the active universe flips the resolved primary', (
      tester,
    ) async {
      Color? resolved;
      await tester.pumpWidget(
        _buildThemedApp(
          initial: MediaKind.anime,
          child: Builder(
            builder: (ctx) {
              resolved = Theme.of(ctx).colorScheme.primary;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, KumoriyaColors.primaryAnime);

      final ctx = tester.element(find.byType(Scaffold));
      ProviderScope.containerOf(
        ctx,
      ).read(activeUniverseProvider.notifier).set(MediaKind.manga);
      await tester.pumpAndSettle();
      expect(resolved, KumoriyaColors.primaryManga);
    });
  });

  group('Slice 7.6 — Wave B: theme overrides follow the accent', () {
    test(
      'forUniverse(anime) sets ProgressIndicator + SnackBar action to anime hue',
      () {
        final theme = KumoriyaTheme.forUniverse(UniverseAccent.anime);
        expect(theme.progressIndicatorTheme.color, KumoriyaColors.primaryAnime);
        expect(
          theme.snackBarTheme.actionTextColor,
          KumoriyaColors.primaryAnime,
        );
        expect(
          theme.bottomNavigationBarTheme.selectedIconTheme?.color,
          KumoriyaColors.primaryAnime,
        );
        expect(
          theme.navigationRailTheme.indicatorColor,
          KumoriyaColors.primaryAnime.withValues(alpha: 0.20),
        );
      },
    );

    test(
      'forUniverse(manga) sets ProgressIndicator + SnackBar action to manga hue',
      () {
        final theme = KumoriyaTheme.forUniverse(UniverseAccent.manga);
        expect(theme.progressIndicatorTheme.color, KumoriyaColors.primaryManga);
        expect(
          theme.snackBarTheme.actionTextColor,
          KumoriyaColors.primaryManga,
        );
        expect(
          theme.bottomNavigationBarTheme.selectedIconTheme?.color,
          KumoriyaColors.primaryManga,
        );
        expect(
          theme.navigationRailTheme.indicatorColor,
          KumoriyaColors.primaryManga.withValues(alpha: 0.20),
        );
      },
    );

    test('FilledButton background resolves to accent.primary per universe', () {
      final animeTheme = KumoriyaTheme.forUniverse(UniverseAccent.anime);
      final mangaTheme = KumoriyaTheme.forUniverse(UniverseAccent.manga);

      final animeBg = animeTheme.filledButtonTheme.style!.backgroundColor!
          .resolve(<WidgetState>{});
      final mangaBg = mangaTheme.filledButtonTheme.style!.backgroundColor!
          .resolve(<WidgetState>{});
      expect(animeBg, KumoriyaColors.primaryAnime);
      expect(mangaBg, KumoriyaColors.primaryManga);

      final animePressedBg = animeTheme
          .filledButtonTheme
          .style!
          .backgroundColor!
          .resolve(<WidgetState>{WidgetState.pressed});
      final mangaPressedBg = mangaTheme
          .filledButtonTheme
          .style!
          .backgroundColor!
          .resolve(<WidgetState>{WidgetState.pressed});
      expect(animePressedBg, KumoriyaColors.primaryAnimeDark);
      expect(mangaPressedBg, KumoriyaColors.primaryMangaDark);
    });
  });
}
