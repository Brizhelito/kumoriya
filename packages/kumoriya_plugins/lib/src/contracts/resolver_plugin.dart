import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/plugin_manifest.dart';
import 'source_plugin.dart' show ExternalSubtitleTrack;

final class ResolvedStream {
  const ResolvedStream({
    required this.url,
    this.qualityLabel,
    this.mimeType,
    this.isHls = false,
    this.headers = const <String, String>{},
  });

  final Uri url;
  final String? qualityLabel;
  final String? mimeType;
  final bool isHls;
  final Map<String, String> headers;
}

/// Bundle returned by [ResolverPlugin.resolve] carrying playable streams
/// and any subtitle tracks discovered during resolution.
final class ResolveResult {
  const ResolveResult({
    required this.streams,
    this.externalSubtitles = const <ExternalSubtitleTrack>[],
  });

  final List<ResolvedStream> streams;
  final List<ExternalSubtitleTrack> externalSubtitles;
}

abstract interface class ResolverPlugin {
  PluginManifest get manifest;
  int get priority;

  bool supports(Uri url);

  Future<Result<ResolveResult, KumoriyaError>> resolve(Uri url);
}
