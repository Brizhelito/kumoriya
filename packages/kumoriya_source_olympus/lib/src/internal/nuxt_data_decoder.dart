import 'dart:convert';

/// Decodes a Nuxt 3 `__NUXT_DATA__` script-tag payload into a regular
/// nested Dart structure (Map / List / primitives).
///
/// The on-wire format is a flat array where every value can be either a
/// primitive (string, num, bool, null) or an integer index pointing to
/// another entry in the same array. Indices are compressed: shared
/// strings, sub-objects and re-used numbers all live exactly once and
/// are referenced by index from anywhere they appear.
///
/// Example (truncated):
///
/// ```text
/// [["ShallowReactive",1],
///  {"data":2,"path":3},
///  {"id":4,"name":5},
///  "/series/comic-foo",
///  127,
///  "Foo"]
/// ```
///
/// Decoding starts at index 0 and dereferences integer values
/// recursively. Special tag arrays (`["ShallowReactive", X]`,
/// `["Reactive", X]`, `["Set"]`) are unwrapped to their inner index or
/// reduced to an empty list, so callers don't have to know about Nuxt's
/// reactivity wrappers.
///
/// The decoder is robust against:
/// - cycles (visited indices return `null` instead of looping);
/// - sparse / out-of-range indices (return `null`);
/// - mixed payloads where a few entries are unreferenced (ignored).
///
/// What it does NOT do:
/// - validate the shape of the decoded tree;
/// - reverse any field-level encoding (HTML entities in strings stay as
///   the source emitted them).
final class NuxtDataDecoder {
  NuxtDataDecoder._();

  /// Decodes [rawJson] (the raw text content of the `__NUXT_DATA__`
  /// script tag) into a nested Dart structure rooted at index 0.
  ///
  /// Throws [FormatException] if the payload is not a top-level JSON
  /// array.
  static Object? decode(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException(
        'Expected __NUXT_DATA__ payload to be a top-level JSON array.',
      );
    }
    return _Resolver(decoded).resolve(0);
  }

  /// Extracts the `__NUXT_DATA__` script-tag content from a full HTML
  /// document and decodes it. Returns `null` when the tag is missing.
  static Object? extractFromHtml(String html) {
    const open = '<script type="application/json" id="__NUXT_DATA__"';
    final start = html.indexOf(open);
    if (start < 0) return null;
    final bodyStart = html.indexOf('>', start);
    if (bodyStart < 0) return null;
    final end = html.indexOf('</script>', bodyStart + 1);
    if (end < 0) return null;
    final body = html.substring(bodyStart + 1, end).trim();
    if (body.isEmpty) return null;
    return decode(body);
  }
}

class _Resolver {
  _Resolver(this._array);

  final List<dynamic> _array;

  /// Top-level entry: dereferences index [idx] (one hop) and walks the
  /// resolved value. The Nuxt convention is that every array slot is a
  /// "concrete" terminal value — primitive or complex — that may
  /// contain integer references to OTHER slots. We must not re-deref a
  /// slot whose own content is a primitive int (that's the literal
  /// value; otherwise we'd treat real numbers like the manga id `1445`
  /// as further references and recurse out of bounds).
  Object? resolve(int idx) => _deref(idx, const <int>{});

  Object? _deref(int idx, Set<int> visited) {
    if (idx < 0 || idx >= _array.length) return null;
    if (visited.contains(idx)) return null;
    final value = _array[idx];
    // A slot whose own content is a primitive (string/num/bool/null)
    // IS the terminal literal. Returning it through `_walk` would
    // misinterpret a literal int (e.g. id=1445) as another reference
    // and recurse out of bounds.
    if (value is num || value is String || value is bool || value == null) {
      return value;
    }
    return _walk(value, <int>{...visited, idx});
  }

  /// Walks a concrete (already-dereffed) value. Primitives are
  /// returned verbatim — their slot has been claimed. Integers found
  /// INSIDE a list/map are references; those need a fresh `_deref`.
  Object? _walk(Object? node, Set<int> visited) {
    if (node is int) {
      // A bare int that came out of a list/map slot is a reference.
      return _deref(node, visited);
    }
    if (node is num || node is String || node is bool || node == null) {
      return node;
    }
    if (node is List) {
      if (node.isNotEmpty && node.first is String) {
        switch (node.first as String) {
          case 'ShallowReactive':
          case 'Reactive':
          case 'EmptyShallowRef':
          case 'EmptyRef':
            return node.length >= 2 ? _walk(node[1], visited) : null;
          case 'Set':
            return node
                .skip(1)
                .map((e) => _walk(e, visited))
                .toList(growable: false);
        }
      }
      return node.map((e) => _walk(e, visited)).toList(growable: false);
    }
    if (node is Map) {
      return <String, Object?>{
        for (final entry in node.entries)
          entry.key as String: _walk(entry.value, visited),
      };
    }
    return null;
  }
}
