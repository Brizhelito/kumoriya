/// Source-side page descriptor.
///
/// One entry per displayable image of a chapter, in render order.
/// `imageUrl` is fetchable directly by the reader; if the source
/// requires custom HTTP headers (e.g. `Referer` for hotlink-protected
/// CDNs), they MUST be attached via [headers] and the source's
/// `MangaSourceCapabilities.requiresPageHeaders` must be `true`.
final class SourcePage {
  const SourcePage({
    required this.index,
    required this.imageUrl,
    this.headers = const <String, String>{},
    this.width,
    this.height,
  }) : assert(index >= 0, 'index must be non-negative');

  /// 0-indexed page position.
  final int index;

  /// Direct image URL. Plugins that need to decrypt or sign URLs do so
  /// before constructing the page; the reader treats this as opaque.
  final Uri imageUrl;

  /// Headers required by the host to serve the image. Reader must apply
  /// them verbatim. Empty map means "no special headers needed".
  final Map<String, String> headers;

  /// Optional pixel dimensions when the source advertises them. Lets
  /// the reader pre-allocate layout slots and avoid reflow on load.
  final int? width;
  final int? height;
}
