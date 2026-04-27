/// ISO 3166-1 alpha-2 country code as exposed by AniList in
/// `Media.countryOfOrigin`.
///
/// Captured as a value type rather than an open `String` so call sites
/// can pattern-match on the well-known cases (JP/KR/CN/TW) when picking
/// reader defaults or filtering "manhwa only" / "manhua only" feeds, and
/// still pass through unknown codes without lossy normalization.
final class MangaCountryOfOrigin {
  const MangaCountryOfOrigin(this.code);

  /// Japan — typical for `MangaFormat.manga` / `oneShot` / `doujinshi`.
  static const MangaCountryOfOrigin jp = MangaCountryOfOrigin('JP');

  /// South Korea — typical for `MangaFormat.manhwa`.
  static const MangaCountryOfOrigin kr = MangaCountryOfOrigin('KR');

  /// China (mainland) — typical for `MangaFormat.manhua`.
  static const MangaCountryOfOrigin cn = MangaCountryOfOrigin('CN');

  /// Taiwan — typical for `MangaFormat.manhua`.
  static const MangaCountryOfOrigin tw = MangaCountryOfOrigin('TW');

  /// Two-letter country code, uppercased on construction is **not**
  /// enforced — callers should pass a normalized value.
  final String code;

  bool get isJapan => code == 'JP';
  bool get isKorea => code == 'KR';
  bool get isChina => code == 'CN' || code == 'TW';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MangaCountryOfOrigin && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'MangaCountryOfOrigin($code)';
}
