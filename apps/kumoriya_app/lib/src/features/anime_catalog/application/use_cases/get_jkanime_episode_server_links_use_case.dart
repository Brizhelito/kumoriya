import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class GetJkanimeEpisodeServerLinksUseCase {
  const GetJkanimeEpisodeServerLinksUseCase({
    required SourcePlugin sourcePlugin,
  }) : _sourcePlugin = sourcePlugin;

  final SourcePlugin _sourcePlugin;
  static const Set<String> _excludedHosts = <String>{'mega.nz'};

  Future<Result<List<SourceServerLink>, KumoriyaError>> call(
    SourceEpisode episode,
  ) async {
    final result = await _sourcePlugin.getEpisodeServerLinks(episode);
    return result.fold(
      onFailure: Failure.new,
      onSuccess: (links) {
        final filtered = links
            .where((link) {
              final host = (link.detectedHost ?? link.initialUrl.host)
                  .toLowerCase()
                  .trim();
              return !_excludedHosts.contains(host);
            })
            .toList(growable: false);
        return Success(filtered);
      },
    );
  }
}
