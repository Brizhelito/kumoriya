import 'package:kumoriya_plugins/kumoriya_plugins.dart';

void main() {
  const manifest = PluginManifest(
    id: 'sample.source',
    displayName: 'Sample Source',
    type: PluginType.source,
    capabilities: <PluginCapability>{PluginCapability.search},
  );
  print('${manifest.id} (${manifest.type.name})');
}
