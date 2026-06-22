import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

import '../../../../app/l10n.dart';
import '../../../player/presentation/pages/player_page.dart';
import 'package:kumoriya_ui/kumoriya_ui.dart';
import '../../../../shared/utils/error_messaging.dart';
import '../providers/anime_catalog_providers.dart';

class ResolveServerLinkPage extends ConsumerWidget {
  const ResolveServerLinkPage({
    super.key,
    required this.anilistId,
    required this.animeTitle,
    required this.episodeNumber,
    required this.sourcePluginId,
    required this.serverLink,
  });

  final int anilistId;
  final String animeTitle;
  final String episodeNumber;
  final String sourcePluginId;
  final SourceServerLink serverLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolutionState = ref.watch(
      resolveSourceServerLinkProvider(serverLink),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.resolverPageTitle(
            animeTitle,
            episodeNumber,
            serverLink.serverName,
          ),
        ),
      ),
      body: resolutionState.when(
        loading: () => LoadingStateView(label: context.l10n.resolverResolving),
        error: (error, _) => ErrorStateView(
          message: context.l10n.unexpectedStateError(error.toString()),
          onRetry: () =>
              ref.invalidate(resolveSourceServerLinkProvider(serverLink)),
        ),
        data: (result) => result.fold(
          onFailure: (error) => ErrorStateView(
            message: mapErrorMessage(context, error),
            onRetry: () =>
                ref.invalidate(resolveSourceServerLinkProvider(serverLink)),
          ),
          onSuccess: (resolved) => ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: resolved.streams.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ListTile(
                      title: Text(
                        context.l10n.resolverUsed(resolved.resolverName),
                      ),
                      subtitle: Text(resolved.resolverId),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlayerPage(
                                anilistId: anilistId,
                                animeTitle: animeTitle,
                                episodeNumber: episodeNumber,
                                sourcePluginId: sourcePluginId,
                                serverName: serverLink.serverName,
                                preferredAudioPreference: switch (serverLink
                                    .language
                                    ?.trim()
                                    .toLowerCase()) {
                                  'sub' => PlaybackAudioPreference.sub,
                                  'dub' ||
                                  'lat' ||
                                  'cast' => PlaybackAudioPreference.dub,
                                  _ => null,
                                },
                                resolved: resolved,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_circle_fill),
                        label: Text(context.l10n.openPlayer),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }

              final stream = resolved.streams[index - 1];
              return ListTile(
                title: Text(stream.url.toString()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.resolverQuality(
                        stream.qualityLabel ??
                            context.l10n.resolverQualityUnknown,
                      ),
                    ),
                    Text(
                      context.l10n.resolverMediaType(
                        stream.isHls
                            ? context.l10n.resolverTypeHls
                            : context.l10n.resolverTypeMp4,
                      ),
                    ),
                    if (stream.mimeType != null)
                      Text(context.l10n.resolverMimeType(stream.mimeType!)),
                    if (stream.headers.isNotEmpty)
                      ...stream.headers.entries.map((entry) {
                        return Text(
                          context.l10n.resolverHeader(entry.key, entry.value),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
