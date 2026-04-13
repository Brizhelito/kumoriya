import 'dart:async';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../services/resolver_registry.dart';

final class GetSourceEpisodeServerLinksUseCase {
  const GetSourceEpisodeServerLinksUseCase({
    required SourcePlugin sourcePlugin,
    required ResolverRegistry registry,
    Duration fetchTimeout = const Duration(seconds: 20),
    this.includeDownloadLinks = false,
  }) : _sourcePlugin = sourcePlugin,
       _registry = registry,
       _fetchTimeout = fetchTimeout;

  final SourcePlugin _sourcePlugin;
  final ResolverRegistry _registry;
  final Duration _fetchTimeout;

  /// When true, both [SourceServerLinkType.stream] and
  /// [SourceServerLinkType.download] links are returned (useful for download
  /// flows where direct-download hosts like Mediafire are valid targets).
  final bool includeDownloadLinks;

  Future<Result<List<SourceServerLink>, KumoriyaError>> call(
    SourceEpisode episode,
  ) async {
    Result<List<SourceServerLink>, KumoriyaError> result;
    try {
      result = await _sourcePlugin
          .getEpisodeServerLinks(episode)
          .timeout(_fetchTimeout);
    } on TimeoutException {
      return Failure(
        SimpleError(
          code: 'source.links_timeout',
          message:
              'Timed out loading episode server links after ${_fetchTimeout.inSeconds}s.',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    return result.fold(
      onFailure: Failure.new,
      onSuccess: (links) {
        final filtered = links
            .where(
              (link) =>
                  link.linkType == SourceServerLinkType.stream ||
                  (includeDownloadLinks &&
                      link.linkType == SourceServerLinkType.download),
            )
            .where(
              (link) =>
                  _registry.selectFor(link.initialUrl) is ResolverSelected,
            )
            .toList(growable: false);

        if (filtered.isEmpty) {
          return const Failure(
            SimpleError(
              code: 'source.no_supported_links',
              message: 'No supported stream links were found for this episode.',
              kind: KumoriyaErrorKind.notFound,
            ),
          );
        }

        return Success(filtered);
      },
    );
  }
}
