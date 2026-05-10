import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

/// Best-effort prefetch of upcoming chapter pages so the next swipes /
/// scroll ticks render without a spinner.
///
/// Resolves the right [ImageProvider] per URL scheme:
/// - `http(s)://` → [CachedNetworkImageProvider] (writes to the same
///   on-disk LRU cache that [MangaPageImage] reads).
/// - `file://`    → [FileImage] (offline pages from a downloaded CBZ).
///
/// Errors are swallowed: prefetch is a UX nicety, never a hard failure.
void precacheNextPages(
  BuildContext context,
  List<MangaPage> pages,
  int currentIndex, {
  int count = 5,
}) {
  if (pages.isEmpty) return;
  final start = currentIndex + 1;
  final end = (currentIndex + count).clamp(0, pages.length - 1);
  for (var i = start; i <= end; i++) {
    if (i < 0 || i >= pages.length) continue;
    final page = pages[i];
    final ImageProvider provider = page.imageUrl.isScheme('file')
        ? FileImage(File(page.imageUrl.toFilePath()))
        : CachedNetworkImageProvider(
            page.imageUrl.toString(),
            headers: page.headers,
          );
    // Fire-and-forget; errors must not surface to the reader.
    // ignore: discarded_futures
    precacheImage(provider, context, onError: (_, _) {});
  }
}
