import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../platform/form_factor_provider.dart';
import '../tokens/cloud_radius.dart';

/// Cache bucket for categorizing image types.
enum CloudImageCacheBucket { artwork, sourceIcon }

/// Cloud-styled visual asset cache manager backed by [flutter_cache_manager].
///
/// Provides separate [CacheManager] instances per [CloudImageCacheBucket]
/// so artwork (90-day stale, 2000 objects) and source icons (30-day stale,
/// 64 objects) have independent eviction policies.
final class CloudVisualCacheManager {
  CloudVisualCacheManager._();

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

  static CacheManager forBucket(CloudImageCacheBucket bucket) {
    return switch (bucket) {
      CloudImageCacheBucket.artwork => artwork,
      CloudImageCacheBucket.sourceIcon => sourceIcons,
    };
  }
}

/// Cloud-styled cached network image with bucket-aware cache management.
///
/// Supports placeholder/error states, optional local file fallback
/// (for offline mode), and cloud design tokens for fallback styling.
class CloudCachedImage extends StatelessWidget {
  const CloudCachedImage({
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
  final CloudImageCacheBucket bucket;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorFallback;
  final String? localFileFallback;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    final fallback = errorFallback ?? _localFileOrFallback(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final safeW = (width != null && width!.isFinite) ? width : null;
    final safeH = (height != null && height!.isFinite) ? height : null;
    final memW = safeW != null ? (safeW * dpr).round() : null;
    final memH = safeH != null ? (safeH * dpr).round() : null;

    final child = trimmed == null || trimmed.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: trimmed,
            cacheManager: CloudVisualCacheManager.forBucket(bucket),
            width: safeW,
            height: safeH,
            memCacheWidth: memW,
            memCacheHeight: memH,
            fit: fit,
            alignment: alignment,
            placeholder: (_, _) => placeholder ?? _placeholderBox(context),
            errorWidget: (_, _, _) => fallback,
          );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _localFileOrFallback(BuildContext context) {
    final path = localFileFallback;
    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, _, _) => _fallbackBox(context),
      );
    }
    return _fallbackBox(context);
  }

  Widget _placeholderBox(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      width: width,
      height: height,
      color: colors.surface2,
      alignment: Alignment.center,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      ),
    );
  }

  Widget _fallbackBox(BuildContext context) {
    final colors = FormFactorProvider.colorsOf(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: borderRadius != null ? borderRadius : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colors.textSoft,
        size: 24,
      ),
    );
  }
}
