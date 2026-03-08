import 'package:kumoriya_core/kumoriya_core.dart';

import '../models/plugin_manifest.dart';

final class ResolvedStream {
  const ResolvedStream({
    required this.url,
    required this.qualityLabel,
    this.headers = const <String, String>{},
  });

  final Uri url;
  final String qualityLabel;
  final Map<String, String> headers;
}

abstract interface class ResolverPlugin {
  PluginManifest get manifest;

  bool supports(Uri url);

  Future<Result<List<ResolvedStream>, KumoriyaError>> resolve(Uri url);
}
