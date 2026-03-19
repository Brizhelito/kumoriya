// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();

  // Test cases: name, anilistId
  final testCases = <(String, int)>[
    ('Oshi no Ko S1', 150672),
    ('Oshi no Ko S2', 166531),
    ('Seitokai Yakuindomo (Seihentai?)', 3636),
    ('Henjin no Salad Bowl', 178548),
  ];

  for (final (name, anilistId) in testCases) {
    print('═══════════════════════════════════════════════');
    print('Testing: $name (AniList ID: $anilistId)');
    print('═══════════════════════════════════════════════');

    // Step 1: Get MAL ID
    final malId = await _getMalId(client, anilistId);
    print('  MAL ID: $malId');
    if (malId == null) {
      print('  ❌ No MAL ID found — AniSkip cannot work');
      print('');
      continue;
    }

    // Step 2: Try AniSkip for episodes 1-3
    for (var ep = 1; ep <= 3; ep++) {
      for (final duration in [1440, 1380, 1320]) {
        final segments = await _fetchAniSkip(client, malId, ep, duration);
        if (segments.isNotEmpty) {
          print('  EP $ep (duration=${duration}s):');
          for (final s in segments) {
            final skipType = s['skip_type'];
            final interval = s['interval'] as Map<String, dynamic>?;
            print('    $skipType: ${interval?['start_time']}s → ${interval?['end_time']}s');
          }
          break;
        }
        if (duration == 1320) {
          print('  EP $ep: ❌ No segments for any duration');
        }
      }
    }
    print('');
  }

  client.close();
}

Future<String> _readResponse(HttpClientResponse response) async {
  return await response.transform(utf8.decoder).join();
}

Future<int?> _getMalId(HttpClient client, int anilistId) async {
  const query = r'''
query($id: Int) {
  Media(id: $id, type: ANIME) {
    idMal
    title { romaji english native }
  }
}
''';
  try {
    final request = await client.postUrl(Uri.parse('https://graphql.anilist.co'));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.write(jsonEncode({'query': query, 'variables': {'id': anilistId}}));
    final response = await request.close();
    if (response.statusCode != 200) {
      print('  AniList HTTP ${response.statusCode}');
      await _readResponse(response);
      return null;
    }
    final body = await _readResponse(response);
    final data = jsonDecode(body);
    final media = data['data']?['Media'];
    if (media != null) {
      print('  Title: ${media['title']}');
    }
    return media?['idMal'] as int?;
  } catch (e) {
    print('  AniList error: $e');
    return null;
  }
}

Future<List<Map<String, dynamic>>> _fetchAniSkip(
  HttpClient client,
  int malId,
  int episodeNumber,
  int episodeLengthSeconds,
) async {
  final uri = Uri.parse(
    'https://api.aniskip.com/v2/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed&episodeLength=$episodeLengthSeconds',
  );
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != 200) {
      await _readResponse(response);
      return [];
    }
    final body = await _readResponse(response);
    final decoded = jsonDecode(body);
    final results = decoded['results'];
    if (results is! List || results.isEmpty) {
      return [];
    }
    return results.cast<Map<String, dynamic>>();
  } catch (e) {
    print('  AniSkip error for ep $episodeNumber: $e');
    return [];
  }
}
