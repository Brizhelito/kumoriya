import 'package:flutter/material.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

import 'manga_page_image.dart';

/// Continuous-scroll reader for manhwa / webtoon.
///
/// Pages render full-width and stack vertically with no spacing
/// between them — the canonical webtoon presentation. Pinch-zoom is
/// available via the `InteractiveViewer` wrapping the whole list,
/// matching the gesture pattern users expect on mobile.
class VerticalReader extends StatefulWidget {
  const VerticalReader({
    super.key,
    required this.pages,
    this.initialScrollOffsetPx,
    this.initialPageIndex = 0,
    this.onScroll,
  });

  final List<MangaPage> pages;
  final double? initialScrollOffsetPx;
  final int initialPageIndex;

  /// Called on every scroll tick with the current pixel offset and a
  /// best-effort approximate page index based on average page height.
  /// Used by the parent reader for resume-progress persistence.
  final void Function(double offsetPx, int approxPageIndex)? onScroll;

  @override
  State<VerticalReader> createState() => _VerticalReaderState();
}

class _VerticalReaderState extends State<VerticalReader> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffsetPx ?? 0,
    );
    _controller.addListener(_emitScroll);

    // If we don't know the scroll offset but we do know an initial
    // page index, jump after first frame so the listview's children
    // have laid out and we can measure.
    if (widget.initialScrollOffsetPx == null && widget.initialPageIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Best-effort: assume uniform page height for the jump. If the
        // user has read past page N, we land "around there"; the
        // image cache handles the visual fidelity.
        final approxOffset = _avgPageHeight() * widget.initialPageIndex;
        _controller.jumpTo(
          approxOffset.clamp(0, _controller.position.maxScrollExtent),
        );
      });
    }
  }

  void _emitScroll() {
    final cb = widget.onScroll;
    if (cb == null) return;
    final offset = _controller.offset;
    final approxIndex = (_avgPageHeight() <= 0)
        ? 0
        : (offset / _avgPageHeight()).floor().clamp(0, widget.pages.length - 1);
    cb(offset, approxIndex);
  }

  double _avgPageHeight() {
    if (!_controller.hasClients) return 0;
    final pos = _controller.position;
    if (pos.maxScrollExtent <= 0 || widget.pages.isEmpty) return 0;
    return (pos.maxScrollExtent + pos.viewportDimension) / widget.pages.length;
  }

  @override
  void dispose() {
    _controller.removeListener(_emitScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 4,
      minScale: 1,
      child: ListView.builder(
        controller: _controller,
        physics: const ClampingScrollPhysics(),
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          final page = widget.pages[index];
          return _ReaderImage(page: page);
        },
      ),
    );
  }
}

/// One full-width page in the vertical reader.
class _ReaderImage extends StatelessWidget {
  const _ReaderImage({required this.page});

  final MangaPage page;

  @override
  Widget build(BuildContext context) {
    return MangaPageImage(page: page, fit: BoxFit.fitWidth);
  }
}
