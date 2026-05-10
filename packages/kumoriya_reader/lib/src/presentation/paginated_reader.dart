import 'package:flutter/material.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'manga_page_image.dart';
import 'page_prefetch.dart';

/// Page-at-a-time reader with horizontal swipes and per-page zoom.
///
/// Uses `PhotoViewGallery` so each page has its own `PhotoView`
/// transformation matrix — pinch-to-zoom on one page does not affect
/// neighbours, and swiping between zoomed pages resets correctly.
class PaginatedReader extends StatefulWidget {
  const PaginatedReader({
    super.key,
    required this.pages,
    this.initialPageIndex = 0,
    this.onPageChanged,
  });

  final List<MangaPage> pages;
  final int initialPageIndex;
  final void Function(int index)? onPageChanged;

  @override
  State<PaginatedReader> createState() => _PaginatedReaderState();
}

class _PaginatedReaderState extends State<PaginatedReader> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPageIndex.clamp(0, widget.pages.length - 1);
    _controller = PageController(initialPage: _currentIndex);
    // Warm the cache for the first batch after the first frame so the
    // BuildContext has an attached ImageConfiguration.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheNextPages(context, widget.pages, _currentIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    widget.onPageChanged?.call(index);
    // Prefetch the next batch so subsequent swipes are instant.
    precacheNextPages(context, widget.pages, index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PhotoViewGallery.builder(
          pageController: _controller,
          itemCount: widget.pages.length,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          onPageChanged: _onPageChanged,
          builder: (context, index) {
            final page = widget.pages[index];
            return PhotoViewGalleryPageOptions.customChild(
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              initialScale: PhotoViewComputedScale.contained,
              child: MangaPageImage(page: page, fit: BoxFit.contain),
            );
          },
          loadingBuilder: (context, _) => const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        ),
        // Subtle page counter in the bottom-right corner.
        Positioned(
          right: 12,
          bottom: 16,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.pages.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
