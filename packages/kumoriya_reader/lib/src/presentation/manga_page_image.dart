import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kumoriya_manga_domain/kumoriya_manga_domain.dart';

/// Renders one [MangaPage] image, picking the right loader based on
/// the URL scheme:
///
/// - `http(s)://` → [CachedNetworkImage] (network-fetched, headers
///   honoured, on-disk LRU cache).
/// - `file://`    → [Image.file] (offline pages extracted from a
///   downloaded CBZ — see Slice 11). No headers, no caching layer.
///
/// Centralised so both [PaginatedReader] and [VerticalReader] stay
/// thin wrappers.
class MangaPageImage extends StatelessWidget {
  const MangaPageImage({
    super.key,
    required this.page,
    this.fit = BoxFit.contain,
  });

  final MangaPage page;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (page.imageUrl.isScheme('file')) {
      return Image.file(
        File(page.imageUrl.toFilePath()),
        fit: fit,
        errorBuilder: (_, _, _) => const _FailedPage(),
      );
    }
    return CachedNetworkImage(
      imageUrl: page.imageUrl.toString(),
      httpHeaders: page.headers,
      fit: fit,
      placeholder: (_, _) =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
      errorWidget: (_, _, _) => const _FailedPage(),
    );
  }
}

class _FailedPage extends StatelessWidget {
  const _FailedPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Failed to load page',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
