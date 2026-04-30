import 'package:drift/native.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftPluginBaseUrlOverrideStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftPluginBaseUrlOverrideStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('returns null for unknown plugin', () async {
    final res = await store.get('kumoriya.source.unknown');
    final value = (res as Success<PluginBaseUrlOverride?, KumoriyaError>).value;
    expect(value, isNull);
  });

  test('persists and reads back override', () async {
    final setRes = await store.set(
      pluginId: 'kumoriya.source.mangadex',
      baseUrl: Uri.parse('https://api.mirror.example/'),
    );
    expect(setRes, isA<Success<void, KumoriyaError>>());

    final getRes = await store.get('kumoriya.source.mangadex');
    final stored =
        (getRes as Success<PluginBaseUrlOverride?, KumoriyaError>).value;
    expect(stored, isNotNull);
    expect(stored!.pluginId, 'kumoriya.source.mangadex');
    expect(stored.baseUrl, Uri.parse('https://api.mirror.example/'));
  });

  test('upserts on second set, last write wins', () async {
    await store.set(pluginId: 'p1', baseUrl: Uri.parse('https://a.example/'));
    await store.set(pluginId: 'p1', baseUrl: Uri.parse('https://b.example/'));

    final res = await store.get('p1');
    final stored =
        (res as Success<PluginBaseUrlOverride?, KumoriyaError>).value;
    expect(stored!.baseUrl, Uri.parse('https://b.example/'));
  });

  test('clear removes the override', () async {
    await store.set(pluginId: 'p1', baseUrl: Uri.parse('https://a.example/'));
    await store.clear('p1');

    final res = await store.get('p1');
    final stored =
        (res as Success<PluginBaseUrlOverride?, KumoriyaError>).value;
    expect(stored, isNull);
  });

  test('rejects empty plugin id with non-fatal failure', () async {
    final res = await store.set(
      pluginId: '',
      baseUrl: Uri.parse('https://a.example/'),
    );
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<void, KumoriyaError>).error.code,
      'storage.plugin_base_url_override_invalid_plugin',
    );
  });

  test('rejects non-http(s) URL', () async {
    final res = await store.set(
      pluginId: 'p1',
      baseUrl: Uri.parse('file:///tmp/x'),
    );
    expect(res.isFailure, isTrue);
    expect(
      (res as Failure<void, KumoriyaError>).error.code,
      'storage.plugin_base_url_override_invalid_url',
    );
  });

  test('getAll returns persisted overrides', () async {
    await store.set(pluginId: 'a', baseUrl: Uri.parse('https://a.example/'));
    await store.set(pluginId: 'b', baseUrl: Uri.parse('https://b.example/'));
    final res = await store.getAll();
    final list =
        (res as Success<List<PluginBaseUrlOverride>, KumoriyaError>).value;
    expect(list.map((e) => e.pluginId).toSet(), <String>{'a', 'b'});
  });
}
