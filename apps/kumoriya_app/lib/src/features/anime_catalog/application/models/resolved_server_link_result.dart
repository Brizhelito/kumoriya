import 'package:kumoriya_plugins/kumoriya_plugins.dart';

final class ResolvedServerLinkResult {
  const ResolvedServerLinkResult({
    required this.resolverId,
    required this.resolverName,
    required this.streams,
    this.externalSubtitles = const <ExternalSubtitleTrack>[],
  });

  final String resolverId;
  final String resolverName;
  final List<ResolvedStream> streams;
  final List<ExternalSubtitleTrack> externalSubtitles;
}
