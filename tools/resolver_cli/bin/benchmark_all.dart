/// Comprehensive resolver benchmark: scrapes real embed URLs from all source
/// plugins for a given anime, then benchmarks each resolver that has a matching
/// URL. Outputs a per-resolver timing report.
///
/// Usage:
///   dart run bin/benchmark_all.dart "naruto"
///   dart run bin/benchmark_all.dart "one piece" --episode=5
///   dart run bin/benchmark_all.dart "jujutsu kaisen" --json

import 'dart:convert';
import 'dart:io';

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';

import '../lib/resolver_catalog.dart';

// ANSI
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _bold = '\x1B[1m';
const _dim = '\x1B[2m';
const _reset = '\x1B[0m';

void main(List<String> arguments) async {
  final jsonOutput = arguments.contains('--json');
  var targetEpisode = 1.0;
  String? query;

  final filteredArgs = <String>[];
  for (final arg in arguments) {
    if (arg.startsWith('--episode=')) {
      targetEpisode =
          double.tryParse(arg.substring('--episode='.length)) ?? 1.0;
    } else if (arg == '--json') {
      // skip
    } else {
      filteredArgs.add(arg);
    }
  }
  query = filteredArgs.join(' ').trim();

  if (query.isEmpty) {
    print('${_bold}Usage:$_reset dart run bin/benchmark_all.dart "anime name"');
    print('  --episode=N   Target episode number (default: 1)');
    print('  --json        Output JSON report');
    exit(1);
  }

  if (!jsonOutput) {
    print('');
    print('${_bold}═══ Kumoriya Resolver Benchmark ═══$_reset');
    print('${_dim}Query: "$query"  |  Episode: $targetEpisode$_reset');
    print('');
  }

  // ── Phase 1: Collect real embed URLs from all source plugins ──────────
  final sources = <String, SourcePlugin>{
    'AnimeFlv': AnimeFlvSourcePlugin(),
    'JKAnime': JkAnimeSourcePlugin(),
    'AnimeAV1': AnimeAv1SourcePlugin(),
  };

  final collectedLinks = <_CollectedLink>[];
  final sourceTimings = <String, int>{};

  for (final entry in sources.entries) {
    final sourceName = entry.key;
    final plugin = entry.value;

    if (!jsonOutput) {
      stdout.write(
          '${_cyan}[$sourceName]$_reset Searching "$query"...');
    }

    final sw = Stopwatch()..start();
    try {
      final searchResult = await plugin.search(
        SourceSearchQuery(query: query),
      );

      final matches = searchResult.fold(
        onSuccess: (m) => m,
        onFailure: (_) => <SourceAnimeMatch>[],
      );

      if (matches.isEmpty) {
        sw.stop();
        sourceTimings[sourceName] = sw.elapsedMilliseconds;
        if (!jsonOutput) print(' ${_yellow}no results$_reset');
        continue;
      }

      final firstMatch = matches.first;
      if (!jsonOutput) {
        stdout.write(
            ' found "${firstMatch.title}" → episodes...');
      }

      final episodesResult = await plugin.getEpisodes(firstMatch.sourceId);
      final episodes = episodesResult.fold(
        onSuccess: (e) => e,
        onFailure: (_) => <SourceEpisode>[],
      );

      // Find target episode
      final episode = episodes.cast<SourceEpisode?>().firstWhere(
            (e) => e!.number == targetEpisode,
            orElse: () => episodes.isNotEmpty ? episodes.first : null,
          );

      if (episode == null) {
        sw.stop();
        sourceTimings[sourceName] = sw.elapsedMilliseconds;
        if (!jsonOutput) print(' ${_yellow}no episodes$_reset');
        continue;
      }

      if (!jsonOutput) {
        stdout.write(' ep${episode.number} → servers...');
      }

      final linksResult = await plugin.getEpisodeServerLinks(episode);
      final links = linksResult.fold(
        onSuccess: (l) => l,
        onFailure: (_) => <SourceServerLink>[],
      );

      sw.stop();
      sourceTimings[sourceName] = sw.elapsedMilliseconds;

      for (final link in links) {
        collectedLinks.add(_CollectedLink(
          source: sourceName,
          serverName: link.serverName,
          url: link.initialUrl,
          language: link.language,
          detectedHost: link.detectedHost,
        ));
      }

      if (!jsonOutput) {
        print(
            ' ${_green}${links.length} links$_reset ${_dim}(${sw.elapsedMilliseconds}ms)$_reset');
      }
    } catch (e) {
      sw.stop();
      sourceTimings[sourceName] = sw.elapsedMilliseconds;
      if (!jsonOutput) {
        print(' ${_red}error: $e$_reset');
      }
    }
  }

  if (collectedLinks.isEmpty) {
    if (!jsonOutput) {
      print('');
      print('${_red}No embed URLs collected. Cannot benchmark.$_reset');
    }
    exit(1);
  }

  // ── Phase 2: Match URLs to resolvers ──────────────────────────────────
  final resolvers = buildAllResolvers();
  final benchTargets = <_BenchTarget>[];

  for (final link in collectedLinks) {
    final resolver = findResolverFor(link.url, resolvers);
    if (resolver != null) {
      benchTargets.add(_BenchTarget(
        link: link,
        resolver: resolver,
      ));
    }
  }

  if (!jsonOutput) {
    print('');
    print(
        '${_bold}Collected ${collectedLinks.length} links → ${benchTargets.length} have resolvers$_reset');

    final unresolvable = collectedLinks
        .where((l) => findResolverFor(l.url, resolvers) == null)
        .toList();
    if (unresolvable.isNotEmpty) {
      print('${_dim}Unresolvable hosts: ${unresolvable.map((l) => l.url.host).toSet().join(', ')}$_reset');
    }
    print('');
  }

  if (benchTargets.isEmpty) {
    if (!jsonOutput) {
      print('${_red}No resolvable links found.$_reset');
    }
    exit(1);
  }

  // ── Phase 3: Benchmark each resolver ──────────────────────────────────
  // Group by resolver ID so we test each resolver once (with its best URL)
  final byResolver = <String, List<_BenchTarget>>{};
  for (final t in benchTargets) {
    byResolver.putIfAbsent(t.resolver.manifest.id, () => []).add(t);
  }

  if (!jsonOutput) {
    print(
        '${_bold}#   Resolver                      Source       Time      Status$_reset');
    print('$_dim${'─' * 90}$_reset');
  }

  final results = <_BenchResult>[];
  var index = 0;

  for (final entry in byResolver.entries) {
    final targets = entry.value;
    index++;

    // Try each URL for this resolver until one succeeds (or all fail)
    _BenchResult? bestResult;

    for (final target in targets) {
      final sw = Stopwatch()..start();
      try {
        final result = await target.resolver.resolve(target.link.url);
        sw.stop();

        final isSuccess = result.fold(
          onSuccess: (_) => true,
          onFailure: (_) => false,
        );
        final errorMsg = result.fold(
          onSuccess: (_) => null,
          onFailure: (e) => '${e.code}: ${e.message}',
        );
        final streamCount = result.fold(
          onSuccess: (r) => r.streams.length,
          onFailure: (_) => 0,
        );

        final br = _BenchResult(
          resolverName: target.resolver.manifest.displayName,
          resolverId: target.resolver.manifest.id,
          priority: target.resolver.priority,
          source: target.link.source,
          serverName: target.link.serverName,
          url: target.link.url.toString(),
          host: target.link.url.host,
          timeMs: sw.elapsedMilliseconds,
          success: isSuccess,
          streamCount: streamCount,
          error: errorMsg,
        );

        if (isSuccess) {
          bestResult = br;
          break; // Got a success, no need to try more URLs
        }

        // Keep the fastest failure if no success yet
        bestResult ??= br;
      } catch (e) {
        sw.stop();
        bestResult ??= _BenchResult(
          resolverName: target.resolver.manifest.displayName,
          resolverId: target.resolver.manifest.id,
          priority: target.resolver.priority,
          source: target.link.source,
          serverName: target.link.serverName,
          url: target.link.url.toString(),
          host: target.link.url.host,
          timeMs: sw.elapsedMilliseconds,
          success: false,
          streamCount: 0,
          error: e.toString(),
        );
      }
    }

    if (bestResult != null) {
      results.add(bestResult);
      if (!jsonOutput) {
        final num = '$index'.padLeft(2);
        final name = bestResult.resolverName.padRight(30);
        final src = bestResult.source.padRight(12);
        final time = '${bestResult.timeMs}ms'.padLeft(8);
        final status = bestResult.success
            ? '$_green✓ ${bestResult.streamCount} streams$_reset'
            : '$_red✗ ${_truncate(bestResult.error ?? 'unknown', 40)}$_reset';
        print('$num  $name $src $time  $status');
      }
    }
  }

  // ── Phase 4: Summary ──────────────────────────────────────────────────
  if (jsonOutput) {
    final report = <String, dynamic>{
      'query': query,
      'targetEpisode': targetEpisode,
      'timestamp': DateTime.now().toIso8601String(),
      'sourceTimings': sourceTimings,
      'totalLinks': collectedLinks.length,
      'resolvableLinks': benchTargets.length,
      'results': results.map((r) => r.toJson()).toList(),
      'summary': _buildSummary(results),
    };
    print(const JsonEncoder.withIndent('  ').convert(report));
  } else {
    print('');
    print('$_dim${'─' * 90}$_reset');

    final succeeded = results.where((r) => r.success).toList();
    final failed = results.where((r) => !r.success).toList();

    print('');
    print('${_bold}═══ Summary ═══$_reset');
    print(
        '  Sources scraped:    ${sources.length} ${_dim}(${sourceTimings.entries.map((e) => '${e.key}: ${e.value}ms').join(', ')})$_reset');
    print(
        '  Total embed links:  ${collectedLinks.length}');
    print(
        '  Resolvers tested:   ${results.length}');
    print(
        '  ${_green}Succeeded:          ${succeeded.length}$_reset');
    print(
        '  ${_red}Failed:             ${failed.length}$_reset');

    if (succeeded.isNotEmpty) {
      final times = succeeded.map((r) => r.timeMs).toList()..sort();
      final avg = (times.reduce((a, b) => a + b) / times.length).round();
      final fastest = times.first;
      final slowest = times.last;

      print('');
      print('${_bold}Timing (successful resolvers):$_reset');
      print('  Fastest:  ${_green}${fastest}ms$_reset  (${succeeded.firstWhere((r) => r.timeMs == fastest).resolverName})');
      print('  Slowest:  ${_yellow}${slowest}ms$_reset  (${succeeded.firstWhere((r) => r.timeMs == slowest).resolverName})');
      print('  Average:  ${avg}ms');

      if (times.length > 1) {
        final median = times[times.length ~/ 2];
        print('  Median:   ${median}ms');
      }

      // Under 1s badge
      final under1s = succeeded.where((r) => r.timeMs < 1000).length;
      final under3s = succeeded.where((r) => r.timeMs < 3000).length;
      print('');
      print(
          '  ${under1s < succeeded.length ? _yellow : _green}< 1 second:  $under1s/${succeeded.length}$_reset');
      print(
          '  ${under3s < succeeded.length ? _yellow : _green}< 3 seconds: $under3s/${succeeded.length}$_reset');
    }

    if (failed.isNotEmpty) {
      print('');
      print('${_bold}Failed resolvers:$_reset');
      for (final f in failed) {
        print(
            '  ${_red}✗$_reset ${f.resolverName} (${f.host}) — ${_truncate(f.error ?? 'unknown', 60)}');
      }
    }

    print('');
  }
}

// ── Models ──────────────────────────────────────────────────────────────────

class _CollectedLink {
  const _CollectedLink({
    required this.source,
    required this.serverName,
    required this.url,
    this.language,
    this.detectedHost,
  });

  final String source;
  final String serverName;
  final Uri url;
  final String? language;
  final String? detectedHost;
}

class _BenchTarget {
  const _BenchTarget({required this.link, required this.resolver});

  final _CollectedLink link;
  final ResolverPlugin resolver;
}

class _BenchResult {
  const _BenchResult({
    required this.resolverName,
    required this.resolverId,
    required this.priority,
    required this.source,
    required this.serverName,
    required this.url,
    required this.host,
    required this.timeMs,
    required this.success,
    required this.streamCount,
    this.error,
  });

  final String resolverName;
  final String resolverId;
  final int priority;
  final String source;
  final String serverName;
  final String url;
  final String host;
  final int timeMs;
  final bool success;
  final int streamCount;
  final String? error;

  Map<String, dynamic> toJson() => {
        'resolver': resolverId,
        'resolverName': resolverName,
        'priority': priority,
        'source': source,
        'serverName': serverName,
        'host': host,
        'url': url,
        'timeMs': timeMs,
        'success': success,
        'streamCount': streamCount,
        if (error != null) 'error': error,
      };
}

Map<String, dynamic> _buildSummary(List<_BenchResult> results) {
  final succeeded = results.where((r) => r.success).toList();
  final times = succeeded.map((r) => r.timeMs).toList()..sort();
  return {
    'total': results.length,
    'succeeded': succeeded.length,
    'failed': results.length - succeeded.length,
    if (times.isNotEmpty) ...{
      'fastestMs': times.first,
      'slowestMs': times.last,
      'avgMs': (times.reduce((a, b) => a + b) / times.length).round(),
      'medianMs': times[times.length ~/ 2],
      'under1s': times.where((t) => t < 1000).length,
      'under3s': times.where((t) => t < 3000).length,
    },
  };
}

String _truncate(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen - 3)}...';
}
