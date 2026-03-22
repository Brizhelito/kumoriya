import 'package:drift/native.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftHlsSegmentStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftHlsSegmentStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  HlsSegment makeSegment({
    required int index,
    String taskId = 'dl-hls-1',
    HlsSegmentStatus status = HlsSegmentStatus.pending,
    String? localPath,
    int? byteSize,
    int retryCount = 0,
  }) {
    return HlsSegment(
      id: '$taskId:seg:$index',
      downloadTaskId: taskId,
      segmentIndex: index,
      url: 'https://cdn.example.com/seg_$index.ts',
      status: status,
      localPath: localPath,
      byteSize: byteSize,
      retryCount: retryCount,
    );
  }

  group('DriftHlsSegmentStore', () {
    group('CRUD', () {
      test('insertSegments and getSegmentsForTask', () async {
        final segments = [
          makeSegment(index: 0),
          makeSegment(index: 1),
          makeSegment(index: 2),
        ];

        final insertResult = await store.insertSegments(segments);
        expect(insertResult.isSuccess, isTrue);

        final getResult = await store.getSegmentsForTask('dl-hls-1');
        final loaded = getResult.fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );

        expect(loaded, hasLength(3));
        expect(loaded[0].segmentIndex, 0);
        expect(loaded[1].segmentIndex, 1);
        expect(loaded[2].segmentIndex, 2);
        expect(loaded[0].status, HlsSegmentStatus.pending);
        expect(loaded[0].url, 'https://cdn.example.com/seg_0.ts');
      });

      test('segments returned in index order', () async {
        // Insert out of order.
        final segments = [
          makeSegment(index: 2),
          makeSegment(index: 0),
          makeSegment(index: 1),
        ];

        await store.insertSegments(segments);

        final getResult = await store.getSegmentsForTask('dl-hls-1');
        final loaded = getResult.fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );

        expect(loaded[0].segmentIndex, 0);
        expect(loaded[1].segmentIndex, 1);
        expect(loaded[2].segmentIndex, 2);
      });

      test('updateSegment changes status and metadata', () async {
        await store.insertSegments([makeSegment(index: 0)]);

        final updated = makeSegment(index: 0).copyWith(
          status: HlsSegmentStatus.completed,
          localPath: '/tmp/seg_00000.ts',
          byteSize: 524288,
        );
        final updateResult = await store.updateSegment(updated);
        expect(updateResult.isSuccess, isTrue);

        final getResult = await store.getSegmentsForTask('dl-hls-1');
        final loaded = getResult.fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );

        expect(loaded[0].status, HlsSegmentStatus.completed);
        expect(loaded[0].localPath, '/tmp/seg_00000.ts');
        expect(loaded[0].byteSize, 524288);
      });

      test('updateSegments batch update', () async {
        await store.insertSegments([
          makeSegment(index: 0),
          makeSegment(index: 1),
          makeSegment(index: 2),
        ]);

        final updates = [
          makeSegment(index: 0).copyWith(status: HlsSegmentStatus.completed),
          makeSegment(index: 1).copyWith(status: HlsSegmentStatus.failed),
        ];
        final batchResult = await store.updateSegments(updates);
        expect(batchResult.isSuccess, isTrue);

        final loaded = (await store.getSegmentsForTask('dl-hls-1')).fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );

        expect(loaded[0].status, HlsSegmentStatus.completed);
        expect(loaded[1].status, HlsSegmentStatus.failed);
        expect(loaded[2].status, HlsSegmentStatus.pending);
      });

      test('deleteSegmentsForTask removes all segments', () async {
        await store.insertSegments([
          makeSegment(index: 0),
          makeSegment(index: 1),
        ]);

        final deleteResult = await store.deleteSegmentsForTask('dl-hls-1');
        expect(deleteResult.isSuccess, isTrue);

        final loaded = (await store.getSegmentsForTask('dl-hls-1')).fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );
        expect(loaded, isEmpty);
      });
    });

    group('counting', () {
      test('countSegmentsByStatus returns correct count', () async {
        await store.insertSegments([
          makeSegment(index: 0).copyWith(status: HlsSegmentStatus.completed),
          makeSegment(index: 1).copyWith(status: HlsSegmentStatus.completed),
          makeSegment(index: 2).copyWith(status: HlsSegmentStatus.pending),
          makeSegment(index: 3).copyWith(status: HlsSegmentStatus.failed),
        ]);

        // We need to update after insert since insert uses default status.
        // Re-insert with correct status by updating.
        await store.updateSegment(
          makeSegment(index: 0).copyWith(status: HlsSegmentStatus.completed),
        );
        await store.updateSegment(
          makeSegment(index: 1).copyWith(status: HlsSegmentStatus.completed),
        );
        await store.updateSegment(
          makeSegment(index: 3).copyWith(status: HlsSegmentStatus.failed),
        );

        final completedCount = (await store.countSegmentsByStatus(
          'dl-hls-1',
          HlsSegmentStatus.completed,
        ))
            .fold(onSuccess: (c) => c, onFailure: (_) => -1);
        expect(completedCount, 2);

        final pendingCount = (await store.countSegmentsByStatus(
          'dl-hls-1',
          HlsSegmentStatus.pending,
        ))
            .fold(onSuccess: (c) => c, onFailure: (_) => -1);
        expect(pendingCount, 1);

        final failedCount = (await store.countSegmentsByStatus(
          'dl-hls-1',
          HlsSegmentStatus.failed,
        ))
            .fold(onSuccess: (c) => c, onFailure: (_) => -1);
        expect(failedCount, 1);
      });
    });

    group('isolation', () {
      test('segments from different tasks are isolated', () async {
        await store.insertSegments([
          makeSegment(index: 0, taskId: 'task-a'),
          makeSegment(index: 1, taskId: 'task-a'),
        ]);
        await store.insertSegments([
          makeSegment(index: 0, taskId: 'task-b'),
        ]);

        final taskA = (await store.getSegmentsForTask('task-a')).fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );
        expect(taskA, hasLength(2));

        final taskB = (await store.getSegmentsForTask('task-b')).fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );
        expect(taskB, hasLength(1));

        // Deleting task-a doesn't affect task-b.
        await store.deleteSegmentsForTask('task-a');

        final afterDelete = (await store.getSegmentsForTask('task-b')).fold(
          onSuccess: (segs) => segs,
          onFailure: (_) => <HlsSegment>[],
        );
        expect(afterDelete, hasLength(1));
      });
    });
  });
}
