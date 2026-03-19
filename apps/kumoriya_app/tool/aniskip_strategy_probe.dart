// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// AniSkip strategy probe — tests 40 popular anime to find the best
/// episodeLength strategy for maximizing OP/ED skip coverage.
Future<void> main() async {
  final client = HttpClient();

  // 40 popular anime: (name, anilistId)
  final testCases = <(String, int)>[
    // --- Current/recent hits ---
    ('Dandadan', 171018),
    ('Solo Leveling', 151807),
    ('Oshi no Ko S1', 150672),
    ('Oshi no Ko S2', 166531),
    ('Jujutsu Kaisen S1', 113415),
    ('Jujutsu Kaisen S2', 145064),
    ('Chainsaw Man', 127230),
    ('Spy x Family S1', 140960),
    ('Spy x Family S2', 158927),
    ('Bocchi the Rock', 130003),
    ('Frieren', 154587),
    ('Mushoku Tensei S1', 108465),
    ('Mushoku Tensei S2', 146065),
    ('Vinland Saga S1', 101348),
    ('Vinland Saga S2', 136430),
    ('Blue Lock', 137822),
    ('Kaguya-sama S1', 101921),
    ('Kaguya-sama S3', 125367),
    ('Demon Slayer S1', 101922),
    ('Demon Slayer S4', 166240),
    // --- Classics / older ---
    ('Attack on Titan S1', 16498),
    ('Attack on Titan Final S3 P2', 162804),
    ('Steins;Gate', 9253),
    ('Death Note', 1535),
    ('Fullmetal Alchemist Brotherhood', 5114),
    ('Hunter x Hunter 2011', 11061),
    ('Naruto Shippuden', 1735),
    ('One Piece', 21),
    ('Mob Psycho 100', 21507),
    ('My Hero Academia S1', 21459),
    // --- Mid-tier / varied ---
    ('Re:Zero S1', 21355),
    ('Konosuba S1', 21202),
    ('Sword Art Online', 11757),
    ('Tokyo Revengers', 120120),
    ('Hell\'s Paradise', 145064), // duplicate JJK S2 anilist, will remap
    ('Jigokuraku', 138715),
    ('Eminence in Shadow', 130298),
    ('Overlord S1', 20832),
    ('Rent-a-Girlfriend S1', 113813),
    ('Horimiya', 124080),
  ];

  // Strategy configs: name → list of episodeLength offsets to try (from base)
  final strategies = <String, List<int>>{
    'exact_only': [0],
    'exact_then_1440': [0, -9999], // -9999 = sentinel for fixed 1440
    'pm15': [0, -15, 15],
    'pm15_pm30': [0, -15, 15, -30, 30],
    'pm15_pm30_1440': [0, -15, 15, -30, 30, -9999],
    'no_length': [-8888], // -8888 = sentinel for omitting episodeLength
    'fixed_1440_only': [-9999],
    'fixed_1420': [-7777], // -7777 = sentinel for fixed 1420
    'pm15_pm30_1420_1440': [0, -15, 15, -30, 30, -7777, -9999],
  };

  // Base episode lengths to simulate real player durations
  final baseLengths = [1437, 1422, 1410, 1445, 1380];

  print('AniSkip Strategy Probe — ${testCases.length} anime');
  print('════════════════════════════════════════════════════════');
  print('');

  // First: resolve all MAL IDs
  final malIds = <int, int?>{};
  final titles = <int, String>{};
  for (final (name, anilistId) in testCases) {
    if (malIds.containsKey(anilistId)) continue;
    titles[anilistId] = name;
    final malId = await _getMalId(client, anilistId);
    malIds[anilistId] = malId;
    if (malId == null) {
      print('  ⚠ $name (AL $anilistId): no MAL ID');
    }
    // Rate limit AniList
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  final validAnime = testCases
      .where((tc) => malIds[tc.$2] != null)
      .toSet()
      .toList();
  print('');
  print('Resolved ${validAnime.length} anime with MAL IDs');
  print('');

  // For each strategy, count how many (anime, episode) pairs we get OP and ED
  final strategyResults = <String, _StrategyResult>{};

  for (final stratEntry in strategies.entries) {
    final stratName = stratEntry.key;
    final offsets = stratEntry.value;
    var totalOp = 0;
    var totalEd = 0;
    var totalBoth = 0;
    var totalAny = 0;
    var totalApiCalls = 0;
    var testedPairs = 0;

    for (final (name, anilistId) in validAnime) {
      final malId = malIds[anilistId]!;
      // Test episodes 1-3
      for (var ep = 1; ep <= 3; ep++) {
        testedPairs++;
        var gotOp = false;
        var gotEd = false;

        for (final baseLen in baseLengths) {
          if (gotOp && gotEd) break;

          for (final offset in offsets) {
            if (gotOp && gotEd) break;

            int? length;
            if (offset == -9999) {
              length = 1440;
            } else if (offset == -8888) {
              length = null; // omit
            } else if (offset == -7777) {
              length = 1420;
            } else {
              length = baseLen + offset;
            }

            totalApiCalls++;
            final segments = await _fetchAniSkip(
              client,
              malId,
              ep,
              length,
            );

            for (final s in segments) {
              final skipType =
                  (s['skip_type'] ?? s['skipType'] ?? '').toString().toLowerCase();
              if (skipType == 'op') gotOp = true;
              if (skipType == 'ed') gotEd = true;
            }

            if (gotOp && gotEd) break;
          }

          // For fixed/no_length strategies, only try once (no baseLen variation)
          if (offsets.length == 1 &&
              (offsets[0] == -9999 || offsets[0] == -8888 || offsets[0] == -7777)) {
            break;
          }
        }

        if (gotOp) totalOp++;
        if (gotEd) totalEd++;
        if (gotOp && gotEd) totalBoth++;
        if (gotOp || gotEd) totalAny++;

        // Rate limit to avoid 429s
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    strategyResults[stratName] = _StrategyResult(
      totalOp: totalOp,
      totalEd: totalEd,
      totalBoth: totalBoth,
      totalAny: totalAny,
      testedPairs: testedPairs,
      totalApiCalls: totalApiCalls,
    );

    print('Strategy "$stratName" done: '
        'OP=$totalOp ED=$totalEd BOTH=$totalBoth ANY=$totalAny '
        'of $testedPairs pairs ($totalApiCalls API calls)');
  }

  // Final summary
  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('STRATEGY COMPARISON (${validAnime.length} anime × 3 episodes)');
  print('═══════════════════════════════════════════════════════════════');
  print('${'Strategy'.padRight(28)} '
      '${'OP'.padLeft(4)} '
      '${'ED'.padLeft(4)} '
      '${'Both'.padLeft(5)} '
      '${'Any'.padLeft(4)} '
      '${'API'.padLeft(5)} '
      '${'OP%'.padLeft(6)} '
      '${'ED%'.padLeft(6)} '
      '${'Any%'.padLeft(6)}');
  print('-' * 78);

  for (final entry in strategyResults.entries) {
    final n = entry.key.padRight(28);
    final r = entry.value;
    final opPct = (100.0 * r.totalOp / r.testedPairs).toStringAsFixed(1);
    final edPct = (100.0 * r.totalEd / r.testedPairs).toStringAsFixed(1);
    final anyPct = (100.0 * r.totalAny / r.testedPairs).toStringAsFixed(1);
    print('$n '
        '${r.totalOp.toString().padLeft(4)} '
        '${r.totalEd.toString().padLeft(4)} '
        '${r.totalBoth.toString().padLeft(5)} '
        '${r.totalAny.toString().padLeft(4)} '
        '${r.totalApiCalls.toString().padLeft(5)} '
        '${opPct.padLeft(6)} '
        '${edPct.padLeft(6)} '
        '${anyPct.padLeft(6)}');
  }

  client.close();
}

class _StrategyResult {
  _StrategyResult({
    required this.totalOp,
    required this.totalEd,
    required this.totalBoth,
    required this.totalAny,
    required this.testedPairs,
    required this.totalApiCalls,
  });
  final int totalOp, totalEd, totalBoth, totalAny, testedPairs, totalApiCalls;
}

Future<int?> _getMalId(HttpClient client, int anilistId) async {
  const query = r'''
query($id: Int) {
  Media(id: $id, type: ANIME) {
    idMal
    title { romaji english }
  }
}
''';
  try {
    final request =
        await client.postUrl(Uri.parse('https://graphql.anilist.co'));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request
        .write(jsonEncode({'query': query, 'variables': {'id': anilistId}}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) return null;
    final data = jsonDecode(body);
    final malId = data['data']?['Media']?['idMal'];
    return malId is int && malId > 0 ? malId : null;
  } catch (_) {
    return null;
  }
}

Future<List<Map<String, dynamic>>> _fetchAniSkip(
  HttpClient client,
  int malId,
  int episodeNumber,
  int? episodeLengthSeconds,
) async {
  final lengthParam =
      episodeLengthSeconds != null ? '&episodeLength=$episodeLengthSeconds' : '';
  final uri = Uri.parse(
    'https://api.aniskip.com/v2/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed$lengthParam',
  );
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final decoded = jsonDecode(body);
    final results = decoded['results'];
    if (results is! List || results.isEmpty) return [];
    return results.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}
