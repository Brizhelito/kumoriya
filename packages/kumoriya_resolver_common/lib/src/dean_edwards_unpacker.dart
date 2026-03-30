/// Dean-Edwards JS packer/unpacker.
///
/// Many video host embeds use `eval(function(p,a,c,k,e,d){...})` to obfuscate
/// stream URLs. This utility extracts and decodes those payloads.
///
/// Used by: StreamWish, MixDrop, VidHide, VOE resolvers.

final _deanEdwardsRe = RegExp(
  r"""eval\(function\(p,a,c,k,e,d\)\{[\s\S]*?return p\}\('([\s\S]*?)',\s*(\d+),\s*(\d+),\s*'([\s\S]*?)'\.split\('\|'\)""",
  caseSensitive: false,
  multiLine: true,
);

/// Unpack all Dean-Edwards packed payloads found in [source].
///
/// Returns a list of decoded strings (one per `eval(...)` block found).
/// Empty list if no packed payloads detected.
List<String> unpackDeanEdwards(String source) {
  final results = <String>[];

  for (final match in _deanEdwardsRe.allMatches(source)) {
    final rawPacked = match.group(1);
    final rawBase = match.group(2);
    final rawCount = match.group(3);
    final rawDictionary = match.group(4);
    if (rawPacked == null ||
        rawBase == null ||
        rawCount == null ||
        rawDictionary == null) {
      continue;
    }

    final base = int.tryParse(rawBase);
    final count = int.tryParse(rawCount);
    if (base == null || count == null || base < 2 || base > 36 || count <= 0) {
      continue;
    }

    final decoded = _decode(
      packed: rawPacked,
      base: base,
      count: count,
      dictionary: rawDictionary,
    );
    if (decoded != null && decoded.trim().isNotEmpty) {
      results.add(decoded);
    }
  }

  return results;
}

/// Build a combined extraction payload: original source + all unpacked blocks.
///
/// Convenience method used by all resolvers that need Dean-Edwards processing.
String buildExtractionPayload(String source) {
  final parts = <String>[source];
  for (final unpacked in unpackDeanEdwards(source)) {
    parts.add(unpacked);
  }
  return parts.join('\n');
}

/// Whether the [source] contains Dean-Edwards packed JS.
bool hasDeanEdwardsPacking(String source) {
  return _deanEdwardsRe.hasMatch(source);
}

String? _decode({
  required String packed,
  required int base,
  required int count,
  required String dictionary,
}) {
  final tokens = dictionary.split('|');
  final decoded = decodeJsEscapes(packed);

  // Build lookup map: base-N key → replacement token.
  final lookup = <String, String>{};
  for (var i = 0; i < count && i < tokens.length; i++) {
    if (tokens[i].isEmpty) continue;
    lookup[i.toRadixString(base)] = tokens[i];
  }
  if (lookup.isEmpty) return decoded;

  // Single-pass: split on word boundaries and substitute known tokens.
  // This replaces N regex compilations + N full-string scans with one pass.
  final wordBoundary = RegExp(r'\b');
  final parts = decoded.split(wordBoundary);
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write(lookup[part] ?? part);
  }
  return buffer.toString();
}

/// Decode JavaScript escape sequences in a string.
///
/// Handles: `\\`, `\/`, `\n`, `\r`, `\t`, `\'`, `\"`,
/// `\xHH` (2-digit hex), `\uHHHH` (4-digit hex).
String decodeJsEscapes(String value) {
  final output = StringBuffer();
  var i = 0;

  while (i < value.length) {
    final char = value[i];
    if (char != '\\') {
      output.write(char);
      i++;
      continue;
    }

    if (i + 1 >= value.length) {
      output.write(char);
      break;
    }

    final next = value[i + 1];
    switch (next) {
      case 'n':
        output.write('\n');
        i += 2;
      case 'r':
        output.write('\r');
        i += 2;
      case 't':
        output.write('\t');
        i += 2;
      case '\'':
      case '"':
      case '\\':
      case '/':
        output.write(next);
        i += 2;
      case 'x':
        final hex = _readHex(value, i + 2, 2);
        if (hex != null) {
          output.writeCharCode(hex);
          i += 4;
        } else {
          output.write(next);
          i += 2;
        }
      case 'u':
        final hex = _readHex(value, i + 2, 4);
        if (hex != null) {
          output.writeCharCode(hex);
          i += 6;
        } else {
          output.write(next);
          i += 2;
        }
      default:
        output.write(next);
        i += 2;
    }
  }

  return output.toString();
}

int? _readHex(String value, int start, int length) {
  if (start + length > value.length) return null;
  return int.tryParse(value.substring(start, start + length), radix: 16);
}
