import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class GetJkanimeEpisodeServerLinksUseCase {
  const GetJkanimeEpisodeServerLinksUseCase({
    required SourcePlugin sourcePlugin,
  }) : _sourcePlugin = sourcePlugin;

  final SourcePlugin _sourcePlugin;

  Future<Result<List<SourceServerLink>, KumoriyaError>> call(
    SourceEpisode episode,
  ) {
    return _sourcePlugin.getEpisodeServerLinks(episode);
  }
}
