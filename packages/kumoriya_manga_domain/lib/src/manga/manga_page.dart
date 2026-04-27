/// A single image page of a chapter.
///
/// `headers` carries any HTTP headers the host requires to serve the
/// image (typically `Referer` and/or `User-Agent`). The reader applies
/// them transparently when fetching.
final class MangaPage {
  const MangaPage({
    required this.index,
    required this.imageUrl,
    this.headers = const <String, String>{},
    this.width,
    this.height,
  });

  final int index;
  final Uri imageUrl;
  final Map<String, String> headers;
  final int? width;
  final int? height;
}
