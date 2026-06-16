import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kumoriya_app/src/app/kumoriya_app.dart';
import 'package:kumoriya_app/src/features/anime_catalog/presentation/providers/storage_providers.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const KumoriyaApp(),
      ),
    );

    // Basic check to see if the app builds without crashing.
    expect(find.byType(KumoriyaApp), findsOneWidget);
  });
}
