// ignore_for_file: avoid_print
/// Mass probe: tests AniSkip API across 35 popular anime with multiple
/// episodeLength values to find the optimal fetch strategy.
///
/// Run from user home dir (outside package context):
///   copy to ~\aniskip_mass_probe.dart && dart run aniskip_mass_probe.dart
import 'dart:convert';
import 'dart:io';

// ── Test dataset: 35 anime covering diverse genres/eras ─────────────────────
// (name, anilistId, episodesToTest)
final _testAnime = <(String, int, List<int>)>[
  // Modern blockbusters
  ('Attack on Titan S1', 16498, [1, 2, 5]),
  ('Demon Slayer S1', 101922, [1, 2, 10]),
  ('Jujutsu Kaisen S1', 113415, [1, 2, 5]),
  ('My Hero Academia S1', 21459, [1, 2, 5]),
  ('Spy x Family S1', 140960, [1, 2, 5]),
  ('Chainsaw Man', 127230, [1, 2, 5]),
  ('Solo Leveling', 151807, [1, 2, 5]),
  ('Dandadan', 171018, [1, 2, 5]),
  ('Frieren', 154587, [1, 2, 5]),
  ('Oshi no Ko S1', 150672, [1, 2, 5]),
  ('Oshi no Ko S2', 166531, [1, 2, 5]),
  // Classics / long-running
  ('Death Note', 1535, [1, 2, 5]),
  ('Fullmetal Alchemist Brotherhood', 5114, [1, 2, 5]),
  ('Steins;Gate', 9253, [1, 2, 5]),
  ('Code Geass', 1575, [1, 2, 5]),
  ('One Punch Man S1', 21087, [1, 2, 5]),
  ('Mob Psycho 100', 21507, [1, 2, 5]),
  ('Vinland Saga S1', 101348, [1, 2, 5]),
  ('Re:Zero S1', 21355, [1, 2, 5]),
  ('Konosuba S1', 21202, [1, 2, 5]),
  // Recent/current
  ('Mushoku Tensei S1', 108465, [1, 2, 5]),
  ('Blue Lock', 137822, [1, 2, 5]),
  ('Bocchi the Rock', 130003, [1, 2, 5]),
  ('Kaguya-sama S1', 101921, [1, 2, 5]),
  ('Cyberpunk Edgerunners', 120377, [1, 2, 5]),
  ('Ranking of Kings', 113717, [1, 2, 5]),
  ('Tokyo Revengers S1', 120120, [1, 2, 5]),
  ('Apothecary Diaries', 161645, [1, 2, 5]),
  ('Kaiju No 8', 162804, [1, 2, 5]),
  ('Wind Breaker', 163270, [1, 2, 5]),
  // Niche / edge cases
  ('Odd Taxi', 128547, [1, 2, 5]),
  ('Summertime Rendering', 129201, [1, 2, 5]),
  ('86 Eighty-Six', 116589, [1, 2, 5]),
  ('Vivy Fluorite Eye', 128546, [1, 2, 5]),
  ('Wonder Egg Priority', 124845, [1, 2, 5]),
];

// ── Episode lengths to probe ────────────────────────────────────────────────
// 0 = special "no episodeLength param" test
final _probeLengths = <int>[1440, 1430, 1420, 1410, 1400, 1380, 1350, 1320, 1500, 0];

// ── Result accumulators ─────────────────────────────────────────────────────
var _totalQueries = 0;
var _totalHits = 0;
var _totalOpHits = 0;
var _totalEdHits = 0;
final _hitsByLength = <int, int>{};
final _opHitsByLength = <int, int>{};
final _firstHitLength = <String, int>{};  // "anilistId:ep" → first length that hit

Future<void> main() async {
  final client = HttpClient();
  final malIdCache = <int, int?>{};

  print('AniSkip Mass Probe — ${_testAnime.length} anime');
  print('Episode lengths to probe: $_probeLengths');
  print('');

  final perAnimeResults = <_AnimeProbeResult>[];

  for (final (name, anilistId, episodes) in _testAnime) {
    stdout.write('[$name] AniList=$anilistId ... ');

    // Get MAL ID (with cache)
    if (!malIdCache.containsKey(anilistId)) {
      malIdCache[anilistId] = await _getMalId(client, anilistId);
    }
    final malId = malIdCache[anilistId];
    if (malId == null) {
      print('❌ No MAL ID');
      perAnimeResults.add(_AnimeProbeResult(name, anilistId, null, {}));
      continue;
    }
    print('MAL=$malId');

    final epResults = <int, _EpisodeProbeResult>{};
    for (final ep in episodes) {
      final lengthResults = <int, List<_SegmentInfo>>{};
      for (final len in _probeLengths) {
        _totalQueries++;
        final segments = await _fetchAniSkip(client, malId, ep, len);
        lengthResults[len] = segments;

        final key = '$anilistId:$ep';
        if (segments.isNotEmpty) {
          _totalHits++;
          _hitsByLength[len] = (_hitsByLength[len] ?? 0) + 1;
          if (segments.any((s) => s.kind == 'op')) {
            _totalOpHits++;
            _opHitsByLength[len] = (_opHitsByLength[len] ?? 0) + 1;
          }
          if (segments.any((s) => s.kind == 'ed')) {
            _totalEdHits++;
          }
          _firstHitLength.putIfAbsent(key, () => len);
        }

        // Rate limit: 150ms between requests
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      epResults[ep] = _EpisodeProbeResult(ep, lengthResults);
    }
    perAnimeResults.add(_AnimeProbeResult(name, anilistId, malId, epResults));
  }

  client.close();

  // ── Print summary ──────────────────────────────────────────────────────
  print('');
  print('═══════════════════════════════════════════════════════════════');
  print(' RESULTS SUMMARY');
  print('═══════════════════════════════════════════════════════════════');
  print('Total API queries: $_totalQueries');
  print('Total hits (any segment): $_totalHits');
  print('Total OP hits: $_totalOpHits');
  print('Total ED hits: $_totalEdHits');
  print('');

  print('── Hits by episodeLength ──');
  for (final len in _probeLengths) {
    final hits = _hitsByLength[len] ?? 0;
    final opHits = _opHitsByLength[len] ?? 0;
    final bar = '█' * (hits ~/ 2) + (hits.isOdd ? '▌' : '');
    print('  len=${len.toString().padLeft(4)}: ${hits.toString().padLeft(3)} hits '
        '(${opHits.toString().padLeft(3)} OP) $bar');
  }
  print('');

  // Per-anime detail
  print('── Per-anime detail ──');
  for (final anime in perAnimeResults) {
    final tag = anime.malId != null ? 'MAL=${anime.malId}' : 'NO MAL';
    print('${anime.name} (AniList=${anime.anilistId}, $tag):');
    if (anime.epResults.isEmpty) {
      print('  (no results)');
      continue;
    }
    for (final ep in anime.epResults.values) {
      final bestLen = _probeLengths.where((l) {
        final segs = ep.byLength[l] ?? [];
        return segs.any((s) => s.kind == 'op');
      }).toList();
      final anyLen = _probeLengths.where((l) {
        return (ep.byLength[l] ?? []).isNotEmpty;
      }).toList();

      if (bestLen.isNotEmpty) {
        print('  EP ${ep.episode}: OP at lengths=$bestLen, '
            'any at lengths=$anyLen');
      } else if (anyLen.isNotEmpty) {
        print('  EP ${ep.episode}: ED-only at lengths=$anyLen');
      } else {
        print('  EP ${ep.episode}: ❌ nothing');
      }
    }
  }

  // Strategy recommendation
  print('');
  print('═══════════════════════════════════════════════════════════════');
  print(' STRATEGY ANALYSIS');
  print('═══════════════════════════════════════════════════════════════');

  // Find which single length covers the most
  final sortedLengths = _hitsByLength.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('Best single length: ${sortedLengths.first.key} '
      '(${sortedLengths.first.value} hits)');

  // Find minimum set of lengths for max coverage
  final allKeys = _firstHitLength.keys.toSet();
  final coveredByBest = <String>{};
  for (final key in _firstHitLength.entries) {
    // Check if best single covers it
    final ep = key.key;
    final anime = perAnimeResults.firstWhere(
      (a) => ep.startsWith('${a.anilistId}:'),
    );
    final epNum = int.parse(ep.split(':')[1]);
    final epResult = anime.epResults[epNum];
    if (epResult != null) {
      final bestSegs = epResult.byLength[sortedLengths.first.key] ?? [];
      if (bestSegs.isNotEmpty) coveredByBest.add(ep);
    }
  }
  print('Coverage with best single: ${coveredByBest.length}/${allKeys.length}');

  // Unique episodes only reachable by non-best lengths
  final unique = allKeys.difference(coveredByBest);
  if (unique.isNotEmpty) {
    print('Episodes ONLY reachable by other lengths:');
    for (final ep in unique) {
      print('  $ep → first hit at length=${_firstHitLength[ep]}');
    }
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Future<String> _readResponse(HttpClientResponse response) async {
  return await response.transform(utf8.decoder).join();
}

Future<int?> _getMalId(HttpClient client, int anilistId) async {
  const query = r'''
query($id: Int) { Media(id: $id, type: ANIME) { idMal } }
''';
  try {
    final request = await client.postUrl(Uri.parse('https://graphql.anilist.co'));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.write(jsonEncode({'query': query, 'variables': {'id': anilistId}}));
    final response = await request.close();
    final body = await _readResponse(response);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(body);
    final malId = data['data']?['Media']?['idMal'];
    return malId is int && malId > 0 ? malId : null;
  } catch (_) {
    return null;
  }
}

Future<List<_SegmentInfo>> _fetchAniSkip(
  HttpClient client,
  int malId,
  int episodeNumber,
  int episodeLengthSeconds,
) async {
  final lenParam = episodeLengthSeconds > 0
      ? '&episodeLength=$episodeLengthSeconds'
      : '';
  final uri = Uri.parse(
    'https://api.aniskip.com/v2/skip-times/$malId/$episodeNumber?types[]=op&types[]=ed$lenParam',
  );
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await _readResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    final decoded = jsonDecode(body);
    final results = decoded['results'];
    if (results is! List || results.isEmpty) return [];

    return results.whereType<Map<String, dynamic>>().map((entry) {
      final skipType = (entry['skip_type'] ?? entry['skipType'] ?? '').toString().toLowerCase();
      final interval = entry['interval'] as Map<String, dynamic>?;
      final start = interval?['start_time'] ?? interval?['startTime'];
      final end = interval?['end_time'] ?? interval?['endTime'];
      return _SegmentInfo(skipType, _toDouble(start), _toDouble(end));
    }).toList();
  } catch (_) {
    return [];
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

// ── Data classes ─────────────────────────────────────────────────────────────

class _SegmentInfo {
  _SegmentInfo(this.kind, this.start, this.end);
  final String kind;
  final double start;
  final double end;
  @override
  String toString() => '$kind(${start.toStringAsFixed(1)}-${end.toStringAsFixed(1)})';
}

class _EpisodeProbeResult {
  _EpisodeProbeResult(this.episode, this.byLength);
  final int episode;
  final Map<int, List<_SegmentInfo>> byLength;
}

class _AnimeProbeResult {
  _AnimeProbeResult(this.name, this.anilistId, this.malId, this.epResults);
  final String name;
  final int anilistId;
  final int? malId;
  final Map<int, _EpisodeProbeResult> epResults;
}
