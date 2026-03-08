import 'plugin_capability.dart';
import 'plugin_type.dart';

final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.displayName,
    required this.type,
    required this.capabilities,
    this.supportedHosts = const <String>[],
    this.baseUrls = const <String>[],
    this.usesWebView = false,
  });

  final String id;
  final String displayName;
  final PluginType type;
  final Set<PluginCapability> capabilities;
  final List<String> supportedHosts;
  final List<String> baseUrls;
  final bool usesWebView;
}
