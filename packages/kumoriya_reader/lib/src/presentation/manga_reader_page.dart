import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/chapter_session.dart';
import '../domain/reader_mode.dart';
import '../domain/reader_progress_sink.dart';
import 'paginated_reader.dart';
import 'vertical_reader.dart';

/// Top-level reader widget. Owns the progress-debounce timer and
/// dispatches to the right inner reader based on `session.mode`.
///
/// Visual chrome (app bar, system UI overlays, error/empty states)
/// lives here so the inner readers stay focused on the page-rendering
/// concern.
class MangaReaderPage extends StatefulWidget {
  const MangaReaderPage({
    super.key,
    required this.session,
    this.progressSink,
    this.progressSaveInterval = const Duration(seconds: 3),
  });

  final ChapterSession session;

  /// Optional resume hook. When null, no progress is persisted.
  final ReaderProgressSink? progressSink;

  /// How often we flush the user's position to the sink while they
  /// scroll / page. Set to a longer interval to reduce write load.
  final Duration progressSaveInterval;

  @override
  State<MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<MangaReaderPage> {
  Timer? _saveTimer;
  int _currentPageIndex = 0;
  double _currentScrollOffsetPx = 0;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.session.initialPageIndex;
    _currentScrollOffsetPx = widget.session.initialScrollOffsetPx ?? 0;
    if (widget.progressSink != null) {
      _saveTimer = Timer.periodic(
        widget.progressSaveInterval,
        (_) => _flushProgress(),
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Final flush so leaving mid-chapter still records the resume point.
    if (widget.progressSink != null) {
      // Fire-and-forget on dispose; the framework cannot await.
      // Intentionally swallowing the future per ReaderProgressSink
      // contract (storage failures are non-fatal here).
      // ignore: discarded_futures
      _flushProgress();
    }
    super.dispose();
  }

  Future<void> _flushProgress({bool completed = false}) async {
    final sink = widget.progressSink;
    if (sink == null) return;
    try {
      await sink.save(
        mangaAnilistId: widget.session.mangaAnilistId,
        sourceId: widget.session.sourceId,
        chapterNumber: widget.session.chapter.number,
        pageIndex: _currentPageIndex,
        scrollOffsetPx: widget.session.mode == ReaderMode.vertical
            ? _currentScrollOffsetPx
            : null,
        completed: completed,
      );
    } catch (_) {
      // Silent: the reader contract says progress save errors are
      // non-fatal. We do not surface them to the user.
    }
  }

  void _onPageChanged(int index) {
    _currentPageIndex = index;
    final isLastPage = index >= widget.session.pages.length - 1;
    if (isLastPage) {
      // Mark the chapter as read on reaching the last page even
      // before the next periodic save fires.
      // ignore: discarded_futures
      _flushProgress(completed: true);
    }
  }

  void _onScroll(double offsetPx, int approxPageIndex) {
    _currentScrollOffsetPx = offsetPx;
    _currentPageIndex = approxPageIndex;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final title =
        session.title ?? 'Chapter ${_formatNumber(session.chapter.number)}';

    if (session.pages.isEmpty) {
      return _ReaderShell(
        title: title,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This chapter has no pages.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final inner = switch (session.mode) {
      ReaderMode.vertical => VerticalReader(
        pages: session.pages,
        initialScrollOffsetPx: session.initialScrollOffsetPx,
        initialPageIndex: session.initialPageIndex,
        onScroll: _onScroll,
      ),
      ReaderMode.paginated => PaginatedReader(
        pages: session.pages,
        initialPageIndex: session.initialPageIndex,
        onPageChanged: _onPageChanged,
      ),
    };

    return _ReaderShell(title: title, child: inner);
  }
}

class _ReaderShell extends StatelessWidget {
  const _ReaderShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      extendBodyBehindAppBar: true,
      body: child,
    );
  }
}

/// Formats `12.0` as `12` and `12.5` as `12.5`. Mirrors the rule the
/// detail page uses so the title stays consistent.
String _formatNumber(double n) {
  if (n == n.truncateToDouble()) return n.toInt().toString();
  return n.toString();
}
