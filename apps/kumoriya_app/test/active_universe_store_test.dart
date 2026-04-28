import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoriya_app/src/shared/universe/active_universe_store.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

void main() {
  late Directory tmp;
  late ActiveUniverseStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('active_universe_store_test_');
    store = ActiveUniverseStore.forTesting(resolveDirectory: () async => tmp);
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('read returns null when the file does not exist', () async {
    expect(await store.read(), isNull);
  });

  test('write then read round-trips the active universe', () async {
    await store.write(MediaKind.manga);
    expect(await store.read(), MediaKind.manga);

    await store.write(MediaKind.anime);
    expect(await store.read(), MediaKind.anime);
  });

  test('read returns null on unknown wire value', () async {
    final file = File(
      '${tmp.path}${Platform.pathSeparator}active_universe.txt',
    );
    await file.writeAsString('lightnovel');
    expect(await store.read(), isNull);
  });

  test('read returns null on empty file', () async {
    final file = File(
      '${tmp.path}${Platform.pathSeparator}active_universe.txt',
    );
    await file.writeAsString('   ');
    expect(await store.read(), isNull);
  });
}
