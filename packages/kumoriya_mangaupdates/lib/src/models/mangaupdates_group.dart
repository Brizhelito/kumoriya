/// A canonical scanlator group record from `/v1/groups/{id}`.
///
/// `active` is the key signal for the picker enrichment slice (M8):
/// inactive groups are demoted in the picker and labeled accordingly.
final class MangaUpdatesGroup {
  const MangaUpdatesGroup({
    required this.id,
    required this.name,
    required this.active,
    this.url,
    this.notes,
    this.siteUrl,
    this.discordUrl,
    this.facebookUrl,
    this.twitterUrl,
    this.associatedNames = const <String>[],
  });

  final int id;
  final String name;

  /// Self-reported activity flag from MangaUpdates moderators.
  /// Default `false` when the API omits the field, since picker
  /// behaviour on missing data should be conservative (treat as
  /// inactive rather than falsely promote the option).
  final bool active;

  final String? url;
  final String? notes;
  final String? siteUrl;
  final String? discordUrl;
  final String? facebookUrl;
  final String? twitterUrl;

  /// Alternate names this group has used (e.g. "MangaReworks"
  /// previously known as "Reworked Scans"). Helpful for matching
  /// scanlator strings emitted by source plugins to canonical MU
  /// groups.
  final List<String> associatedNames;
}
