import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:test/test.dart';

void main() {
  test('manifest keeps plugin type and capabilities', () {
    const manifest = PluginManifest(
      id: 'example.source',
      displayName: 'Example Source',
      type: PluginType.source,
      capabilities: <PluginCapability>{PluginCapability.search},
    );

    expect(manifest.type, PluginType.source);
    expect(manifest.capabilities.contains(PluginCapability.search), isTrue);
  });
}
