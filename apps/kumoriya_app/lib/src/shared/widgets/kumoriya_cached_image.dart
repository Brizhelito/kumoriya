import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum KumoriyaImageCacheBucket { artwork, sourceIcon }

final class KumoriyaVisualCacheManager {
  KumoriyaVisualCacheManager._();

  static final CacheManager artwork = CacheManager(
    Config(
      'kumoriya-artwork-cache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 2000,
    ),
  );

  static final CacheManager sourceIcons = CacheManager(
    Config(
      'kumoriya-source-icon-cache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 64,
    ),
  );

  static CacheManager forBucket(KumoriyaImageCacheBucket bucket) {
    return switch (bucket) {
      KumoriyaImageCacheBucket.artwork => artwork,
      KumoriyaImageCacheBucket.sourceIcon => sourceIcons,
    };
  }
}

class KumoriyaCachedImage extends StatelessWidget {
  const KumoriyaCachedImage({
    super.key,
    required this.url,
    required this.bucket,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.errorFallback,
    this.localFileFallback,
  });

  final String? url;
  final KumoriyaImageCacheBucket bucket;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorFallback;

  /// Optional local file path used as a fallback when the network image fails
  /// (e.g. offline mode with a cleared cache). Persisted cover images for
  /// downloaded anime use this to guarantee offline display.
  final String? localFileFallback;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    final fallback = errorFallback ?? _localFileOrFallback();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = width != null ? (width! * dpr).round() : null;
    final memH = height != null ? (height! * dpr).round() : null;
    final child = trimmed == null || trimmed.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: trimmed,
            cacheManager: KumoriyaVisualCacheManager.forBucket(bucket),
            width: width,
            height: height,
            memCacheWidth: memW,
            memCacheHeight: memH,
            fit: fit,
            alignment: alignment,
            placeholder: (_, _) => placeholder ?? _placeholderBox(context),
            errorWidget: (_, _, _) => fallback,
          );

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _localFileOrFallback() {
    final path = localFileFallback;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => _fallbackBox(),
      );
    }
    return _fallbackBox();
  }

  Widget _placeholderBox(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _fallbackBox() {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0x14000000)),
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    );
  }
}
