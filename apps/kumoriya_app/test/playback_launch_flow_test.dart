import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/episode_playback.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/models/source_availability.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/anime_catalog_providers.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/support/playback_launch_flow.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  testWidgets(
    'server picker groups by source and returns remember-selection choice',
    (tester) async {
      ServerPickerSelection? selection;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      selection = await showServerPicker(
                        context,
                        options: _options,
                        autoSelectionFailed: false,
                        rememberedPreference: PlaybackPreference(
                          anilistId: 1,
                          preferredSourcePluginId: 'kumoriya.source.animeflv',
                          preferredServerName: 'Okru',
                          preferredResolverPluginId: 'kumoriya.resolver.okru',
                          updatedAt: DateTime(2026, 3, 9),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Todas las fuentes'), findsOneWidget);
      expect(find.textContaining('AnimeFLV'), findsWidgets);
      expect(find.textContaining('JKAnime'), findsWidgets);
      expect(find.text('Recordar esta seleccion'), findsOneWidget);

      await tester.tap(find.textContaining('JKAnime').first);
      await tester.pumpAndSettle();

      expect(find.text('BetaServer'), findsOneWidget);
      expect(find.text('Okru'), findsNothing);

      await tester.tap(find.text('BetaServer'));
      await tester.pumpAndSettle();

      expect(selection, isNotNull);
      expect(selection!.option.serverLink.serverName, 'BetaServer');
      expect(selection!.rememberSelection, isTrue);
    },
  );

  testWidgets(
    'single remaining option resolves directly without reopening the picker',
    (tester) async {
      var unavailableCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolveSourceServerLinkUseCaseProvider.overrideWithValue(
              ResolveSourceServerLinkUseCase(
                registry: ResolverRegistry(
                  resolvers: <ResolverPlugin>[const _FailingResolverPlugin()],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        await handlePlaybackDecision(
                          context: context,
                          ref: ref,
                          anilistId: 1,
                          animeTitle: 'Frieren',
                          decision: EpisodePlaybackDecision.selection(
                            options: <EpisodePlaybackOption>[_options.first],
                            autoSelectionFailed: true,
                          ),
                          onUnavailable: () {
                            unavailableCalls += 1;
                          },
                        );
                      },
                      child: const Text('launch'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('launch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose a server'), findsNothing);
      expect(unavailableCalls, 1);
    },
  );
}

final List<EpisodePlaybackOption> _options = <EpisodePlaybackOption>[
  EpisodePlaybackOption(
    sourcePluginId: 'kumoriya.source.animeflv',
    sourceName: 'AnimeFLV',
    sourceIconUrl: null,
    sourceEpisode: SourceEpisode(
      sourceEpisodeId: '1',
      number: 1,
      title: 'Episode 1',
      episodeUrl: Uri.parse('https://example.com/flv/1'),
    ),
    serverLink: SourceServerLink(
      serverId: 'okru',
      serverName: 'Okru',
      initialUrl: Uri.parse('https://ok.ru/videoembed/1'),
      detectedHost: 'ok.ru',
      language: 'sub',
    ),
    resolverId: 'kumoriya.resolver.okru',
    resolverName: 'Okru Resolver',
    audioKind: SourceAudioKind.sub,
    isRecommended: true,
  ),
  EpisodePlaybackOption(
    sourcePluginId: 'kumoriya.source.animeflv',
    sourceName: 'AnimeFLV',
    sourceIconUrl: null,
    sourceEpisode: SourceEpisode(
      sourceEpisodeId: '1',
      number: 1,
      title: 'Episode 1',
      episodeUrl: Uri.parse('https://example.com/flv/1'),
    ),
    serverLink: SourceServerLink(
      serverId: 'netu',
      serverName: 'Netu',
      initialUrl: Uri.parse('https://hqq.tv/e/1'),
      detectedHost: 'hqq.tv',
      language: 'sub',
    ),
    resolverId: 'kumoriya.resolver.hqq',
    resolverName: 'Netu / HQQ Resolver',
    audioKind: SourceAudioKind.sub,
  ),
  EpisodePlaybackOption(
    sourcePluginId: 'kumoriya.source.jkanime',
    sourceName: 'JKAnime',
    sourceIconUrl: null,
    sourceEpisode: SourceEpisode(
      sourceEpisodeId: '1',
      number: 1,
      title: 'Episode 1',
      episodeUrl: Uri.parse('https://example.com/jk/1'),
    ),
    serverLink: SourceServerLink(
      serverId: 'beta',
      serverName: 'BetaServer',
      initialUrl: Uri.parse('https://streamwish.to/e/1'),
      detectedHost: 'streamwish.to',
      language: 'dub',
    ),
    resolverId: 'kumoriya.resolver.streamwish',
    resolverName: 'StreamWish Resolver',
    audioKind: SourceAudioKind.dub,
  ),
];

class _FailingResolverPlugin implements ResolverPlugin {
  const _FailingResolverPlugin();

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'kumoriya.resolver.failing',
    displayName: 'Failing Resolver',
    type: PluginType.resolver,
    capabilities: <PluginCapability>{PluginCapability.streamResolution},
  );

  @override
  int get priority => 100;

  @override
  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url) async {
    return const Failure(
      SimpleError(
        code: 'resolver.failed',
        message: 'boom',
        kind: KumoriyaErrorKind.transport,
      ),
    );
  }

  @override
  bool supports(Uri url) => true;
}
