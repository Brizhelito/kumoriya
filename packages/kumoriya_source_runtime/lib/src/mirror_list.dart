/// Ordered, non-empty list of equivalent base URIs for a single source plugin.
///
/// The first entry is the preferred mirror. Plugins MUST treat all entries as
/// fully interchangeable — same API shape, same auth model, same canonical
/// responses. If two endpoints are not interchangeable they belong in
/// different `MirrorList`s.
final class MirrorList {
  /// Builds a non-empty list. Throws [ArgumentError] when [entries] is empty.
  ///
  /// Entries are normalized to ensure each ends with a trailing slash, so
  /// callers can resolve relative paths via `Uri.resolve`/`resolveUri`
  /// without losing the last path segment.
  factory MirrorList(List<Uri> entries) {
    if (entries.isEmpty) {
      throw ArgumentError.value(
        entries,
        'entries',
        'MirrorList requires at least one base URI.',
      );
    }
    final normalized = List<Uri>.unmodifiable(entries.map(_normalize));
    return MirrorList._(normalized);
  }

  /// Convenience constructor when the source has a single mirror.
  factory MirrorList.single(Uri uri) => MirrorList(<Uri>[uri]);

  const MirrorList._(this.entries);

  final List<Uri> entries;

  Uri get primary => entries.first;
  int get length => entries.length;

  /// Returns a new [MirrorList] with [override] in front and any duplicate
  /// entry from the rest deduplicated. Use this to honor per-plugin user
  /// overrides without losing the manifest fallbacks.
  MirrorList withPreferred(Uri override) {
    final normalizedOverride = _normalize(override);
    final rest = entries.where((e) => e != normalizedOverride);
    return MirrorList(<Uri>[normalizedOverride, ...rest]);
  }

  static Uri _normalize(Uri uri) {
    final path = uri.path;
    if (path.endsWith('/')) {
      return uri;
    }
    return uri.replace(path: '$path/');
  }

  @override
  String toString() => 'MirrorList(${entries.join(', ')})';
}
