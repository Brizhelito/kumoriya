import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  late AppDatabase db;
  late DriftSourceAvailabilityStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSourceAvailabilityStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'replaces and retrieves cached availability rows for an anime',
    () async {
      final replaceResult = await store
          .replaceAvailability(1001, <SourceAvailabilityCacheRecord>[
            SourceAvailabilityCacheRecord(
              anilistId: 1001,
              sourcePluginId: 'kumoriya.source.animeflv',
              payloadJson: '{"status":"available"}',
              updatedAt: DateTime(2026, 3, 9, 10),
            ),
            SourceAvailabilityCacheRecord(
              anilistId: 1001,
              sourcePluginId: 'kumoriya.source.jkanime',
              payloadJson: '{"status":"unavailable"}',
              updatedAt: DateTime(2026, 3, 9, 10),
            ),
          ]);

      expect(replaceResult, isA<Success<void, KumoriyaError>>());

      final readResult = await store.getAvailability(1001);
      final rows =
          (readResult
                  as Success<
                    List<SourceAvailabilityCacheRecord>,
                    KumoriyaError
                  >)
              .value;

      expect(rows.length, 2);
      expect(
        rows.map((row) => row.sourcePluginId),
        containsAll(<String>[
          'kumoriya.source.animeflv',
          'kumoriya.source.jkanime',
        ]),
      );
    },
  );

  test('clearAvailability removes all rows for the anime', () async {
    await store.replaceAvailability(1002, <SourceAvailabilityCacheRecord>[
      SourceAvailabilityCacheRecord(
        anilistId: 1002,
        sourcePluginId: 'kumoriya.source.animeflv',
        payloadJson: '{"status":"available"}',
        updatedAt: DateTime(2026, 3, 9, 10),
      ),
    ]);

    final clearResult = await store.clearAvailability(1002);
    expect(clearResult, isA<Success<void, KumoriyaError>>());

    final readResult = await store.getAvailability(1002);
    final rows =
        (readResult
                as Success<List<SourceAvailabilityCacheRecord>, KumoriyaError>)
            .value;
    expect(rows, isEmpty);
  });
}
