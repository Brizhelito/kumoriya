import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../services/resolver_registry.dart';

final class GetSourceEpisodeServerLinksUseCase {
  const GetSourceEpisodeServerLinksUseCase({
    required SourcePlugin sourcePlugin,
    required ResolverRegistry registry,
  }) : _sourcePlugin = sourcePlugin,
       _registry = registry;

  final SourcePlugin _sourcePlugin;
  final ResolverRegistry _registry;

  Future<Result<List<SourceServerLink>, KumoriyaError>> call(
    SourceEpisode episode,
  ) async {
    final result = await _sourcePlugin.getEpisodeServerLinks(episode);
    return result.fold(
      onFailure: Failure.new,
      onSuccess: (links) {
        final filtered = links
            .where((link) => link.linkType == SourceServerLinkType.stream)
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
