/// Download Pipeline Playground
///
/// End-to-end audit of the entire download pipeline for a given anime:
///   source search → episode listing → server links → resolver →
///   download probe (HEAD + first bytes) → full report.
///
/// Usage:
///   dart run bin/download_playground.dart "jujutsu kaisen"
///   dart run bin/download_playground.dart "naruto" --episode=5
///   dart run bin/download_playground.dart "one piece" --episode=1 --source=JKAnime
///   dart run bin/download_playground.dart "naruto" --full-download --download-dir=./dl_test
///   dart run bin/download_playground.dart "naruto" --json --output=report.json
///
/// Flags:
///   --episode=N          Target episode number (default: 1)
///   --source=NAME        Only test a specific source (JKAnime, AnimeFlv, AnimeAV1, AnimeNexus)
///   --resolver=NAME      Only test a specific resolver
///   --full-download      Download full files (not just probe)
///   --download-dir=PATH  Where to save downloaded files (default: ./download_playground_out)
///   --probe-bytes=N      How many bytes to download in probe mode (default: 512KB)
///   --timeout=N          Resolver timeout in seconds (default: 25)
///   --json               Output JSON report
///   --output=FILE        Write report to file instead of stdout
///   --verbose            Show extra debug info

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart' show AnimeFormat;
import 'package:kumoriya_matching/kumoriya_matching.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_source_animeflv/kumoriya_source_animeflv.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';
import 'package:kumoriya_source_anime_nexus/kumoriya_source_anime_nexus.dart';
import 'package:kumoriya_source_jkanime/kumoriya_source_jkanime.dart';

import '../lib/resolver_catalog.dart';

// ─── ANSI ────────────────────────────────────────────────────────────────────
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _magenta = '\x1B[35m';
const _bold = '\x1B[1m';
const _dim = '\x1B[2m';
const _reset = '\x1B[0m';

// ─── Config ──────────────────────────────────────────────────────────────────
class _Config {
  String query = '';
  double targetEpisode = 1.0;
  String? sourceFilter;
  String? resolverFilter;
  bool fullDownload = false;
  String downloadDir = './download_playground_out';
  int probeBytes = 512 * 1024; // 512 KB
  int timeoutSeconds = 25;
  bool jsonOutput = false;
  String? outputFile;
  bool verbose = false;
  // Matching hints (build CanonicalSeries from query + optional metadata)
  int? matchingYear;
  String? matchingFormat;
  int? matchingEpisodes;
  List<String> matchingAliases = [];
  int? anilistId;
}

// ─── Models ──────────────────────────────────────────────────────────────────

class _SourceResult {
  _SourceResult({required this.sourceName, required this.pluginId});

  final String sourceName;
  final String pluginId;
  int searchTimeMs = 0;
  int episodeTimeMs = 0;
  int serverLinksTimeMs = 0;
  String? matchedTitle;
  String? matchedSourceId;
  // Matching diagnostics
  String? matchVerdict;        // autoMatch | reviewNeeded | fallback
  double? matchScore;
  List<String> matchReasons = [];
  int matchCandidateCount = 0;
  //
  int episodeCount = 0;
  int serverLinkCount = 0;
  String? error;
  final serverLinks = <SourceServerLink>[];
}

class _ServerLinkResult {
  _ServerLinkResult({
    required this.sourceName,
    required this.serverLink,
  });

  final String sourceName;
  final SourceServerLink serverLink;

  // Resolver phase
  String? resolverName;
  String? resolverId;
  int resolverPriority = 0;
  int resolveTimeMs = 0;
  bool resolveSuccess = false;
  String? resolveError;
  String? resolveErrorCode;
  int streamCount = 0;
  int subtitleCount = 0;
  final resolvedStreams = <_StreamInfo>[];

  // Download probe phase
  bool downloadProbed = false;
  int probeTimeMs = 0;
  bool probeSuccess = false;
  String? probeError;
  int probeBytesReceived = 0;
  int? probeTotalBytes;
  bool probeSupportsRanges = false;
  String? probeContentType;
  int? probeStatusCode;
  Map<String, String> probeResponseHeaders = {};

  // Full download phase
  bool fullDownloaded = false;
  int downloadTimeMs = 0;
  bool downloadSuccess = false;
  String? downloadError;
  int downloadBytesReceived = 0;
  String? downloadPath;

  Map<String, dynamic> toJson() => {
        'source': sourceName,
        'server': serverLink.serverName,
        'initialUrl': serverLink.initialUrl.toString(),
        'detectedHost': serverLink.detectedHost,
        'language': serverLink.language,
        'linkType': serverLink.linkType.name,
        // resolver
        'resolver': {
          'name': resolverName,
          'id': resolverId,
          'priority': resolverPriority,
          'timeMs': resolveTimeMs,
          'success': resolveSuccess,
          'error': resolveError,
          'errorCode': resolveErrorCode,
          'streamCount': streamCount,
          'subtitleCount': subtitleCount,
          'streams': resolvedStreams.map((s) => s.toJson()).toList(),
        },
        // probe
        'probe': {
          'tested': downloadProbed,
          'timeMs': probeTimeMs,
          'success': probeSuccess,
          'error': probeError,
          'bytesReceived': probeBytesReceived,
          'totalBytes': probeTotalBytes,
          'supportsRanges': probeSupportsRanges,
          'contentType': probeContentType,
          'statusCode': probeStatusCode,
          'responseHeaders': probeResponseHeaders,
        },
        // full download
        if (fullDownloaded)
          'download': {
            'timeMs': downloadTimeMs,
            'success': downloadSuccess,
            'error': downloadError,
            'bytesReceived': downloadBytesReceived,
            'path': downloadPath,
          },
      };
}

class _StreamInfo {
  _StreamInfo({
    required this.url,
    this.qualityLabel,
    this.mimeType,
    this.isHls = false,
    this.headers = const {},
  });

  final String url;
  final String? qualityLabel;
  final String? mimeType;
  final bool isHls;
  final Map<String, String> headers;

  Map<String, dynamic> toJson() => {
        'url': url,
        'quality': qualityLabel,
        'mime': mimeType,
        'isHls': isHls,
        'headers': headers,
      };
}

// ─── Main ────────────────────────────────────────────────────────────────────

void main(List<String> arguments) async {
  final config = _parseArgs(arguments);
  if (config == null) return;

  final allResults = <_ServerLinkResult>[];
  final sourceResults = <_SourceResult>[];
  final globalSw = Stopwatch()..start();

  // ── Phase 1: Collect server links from sources ─────────────────────────
  final sources = _buildSources(config);
  final canonical = await _buildCanonical(config);

  if (!config.jsonOutput) {
    _printHeader(config);
    if (config.anilistId != null) {
      print(
        '${_cyan}AniList canonical:$_reset "${canonical.primaryTitle}" '
        '${_dim}(${canonical.format.name}, '
        '${canonical.releaseYear ?? "?"} yr, '
        '${canonical.episodeCount ?? "?"} eps)$_reset',
      );
      print('');
    }
  }

  for (final entry in sources.entries) {
    final sourceResult = await _collectFromSource(
      entry.key,
      entry.value,
      config,
      canonical,
    );
    sourceResults.add(sourceResult);

    for (final link in sourceResult.serverLinks) {
      allResults.add(_ServerLinkResult(
        sourceName: sourceResult.sourceName,
        serverLink: link,
      ));
    }
  }

  if (!config.jsonOutput) {
    print('');
    print(
        '${_bold}Total server links collected: ${allResults.length}$_reset');
    print('');
  }

  if (allResults.isEmpty) {
    if (!config.jsonOutput) {
      print('${_red}No server links found. Cannot test pipeline.$_reset');
    }
    _writeReport(config, sourceResults, allResults, globalSw);
    exit(1);
  }

  // ── Phase 2: Resolve each server link ──────────────────────────────────
  final resolvers = buildAllResolvers();

  if (!config.jsonOutput) {
    print('$_bold═══ Phase 2: Resolution ═══$_reset');
    print('');
  }

  for (final result in allResults) {
    await _resolveServerLink(result, resolvers, config);
  }

  // ── Phase 3: Download probe / full download ────────────────────────────
  if (!config.jsonOutput) {
    print('');
    print('$_bold═══ Phase 3: Download ${config.fullDownload ? "(Full)" : "(Probe)"} ═══$_reset');
    print('');
  }

  final httpClient = http.Client();
  try {
    for (final result in allResults) {
      if (!result.resolveSuccess || result.resolvedStreams.isEmpty) continue;
      await _probeOrDownload(result, httpClient, config);
    }
  } finally {
    httpClient.close();
  }

  // ── Phase 4: Report ────────────────────────────────────────────────────
  globalSw.stop();

  if (!config.jsonOutput) {
    _printSummary(sourceResults, allResults, globalSw);
  }

  _writeReport(config, sourceResults, allResults, globalSw);
}

// ─── Arg parsing ─────────────────────────────────────────────────────────────

_Config? _parseArgs(List<String> arguments) {
  final config = _Config();
  final positional = <String>[];

  for (final arg in arguments) {
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      return null;
    } else if (arg.startsWith('--episode=')) {
      config.targetEpisode =
          double.tryParse(arg.substring('--episode='.length)) ?? 1.0;
    } else if (arg.startsWith('--source=')) {
      config.sourceFilter = arg.substring('--source='.length);
    } else if (arg.startsWith('--resolver=')) {
      config.resolverFilter = arg.substring('--resolver='.length);
    } else if (arg == '--full-download') {
      config.fullDownload = true;
    } else if (arg.startsWith('--download-dir=')) {
      config.downloadDir = arg.substring('--download-dir='.length);
    } else if (arg.startsWith('--probe-bytes=')) {
      config.probeBytes =
          int.tryParse(arg.substring('--probe-bytes='.length)) ??
              (512 * 1024);
    } else if (arg.startsWith('--timeout=')) {
      config.timeoutSeconds =
          int.tryParse(arg.substring('--timeout='.length)) ?? 25;
    } else if (arg == '--json') {
      config.jsonOutput = true;
    } else if (arg.startsWith('--output=')) {
      config.outputFile = arg.substring('--output='.length);
    } else if (arg == '--verbose' || arg == '-v') {
      config.verbose = true;
    } else if (arg.startsWith('--year=')) {
      config.matchingYear = int.tryParse(arg.substring('--year='.length));
    } else if (arg.startsWith('--format=')) {
      config.matchingFormat = arg.substring('--format='.length);
    } else if (arg.startsWith('--episodes=')) {
      config.matchingEpisodes =
          int.tryParse(arg.substring('--episodes='.length));
    } else if (arg.startsWith('--aliases=')) {
      config.matchingAliases = arg
          .substring('--aliases='.length)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (arg.startsWith('--anilist-id=')) {
      config.anilistId =
          int.tryParse(arg.substring('--anilist-id='.length));
    } else {
      positional.add(arg);
    }
  }

  config.query = positional.join(' ').trim();
  if (config.query.isEmpty) {
    _printUsage();
    return null;
  }

  return config;
}

void _printUsage() {
  print('''
${_bold}Kumoriya Download Pipeline Playground$_reset

Tests the full download pipeline: source → episodes → servers → resolve → download.

${_cyan}Usage:$_reset
  dart run bin/download_playground.dart "anime name" [options]

${_cyan}Options:$_reset
  --episode=N          Target episode number (default: 1)
  --source=NAME        Only test a specific source (JKAnime, AnimeFlv, AnimeAV1, AnimeNexus)
  --resolver=NAME      Only test a specific resolver
  --full-download      Download full files, not just probe
  --download-dir=PATH  Where to save files (default: ./download_playground_out)
  --probe-bytes=N      Probe download size in bytes (default: 524288 = 512KB)
  --timeout=N          Resolver timeout in seconds (default: 25)
  --json               Output JSON report to stdout
  --output=FILE        Write JSON report to file
  --verbose            Show extra debug info

${_cyan}Matching hints (improve source selection accuracy):$_reset
  --year=N             Release year  (e.g. --year=2023)
  --format=FORMAT      Anime format  (TV | MOVIE | OVA | ONA | SPECIAL)
  --episodes=N         Total episode count (e.g. --episodes=24)
  --aliases=LIST       Comma-separated title aliases (e.g. --aliases="JJK,呪術廻戦")
  --anilist-id=N       AniList ID for authoritative metadata (fetches from AniList API)

${_cyan}Examples:$_reset
  dart run bin/download_playground.dart "jujutsu kaisen"
  dart run bin/download_playground.dart "naruto" --episode=5 --verbose
  dart run bin/download_playground.dart "one piece" --source=JKAnime --output=report.json
  dart run bin/download_playground.dart "naruto" --full-download --download-dir=./test_dl
  dart run bin/download_playground.dart "attack on titan" --year=2013 --format=TV --episodes=25
  dart run bin/download_playground.dart "jujutsu kaisen" --anilist-id=113415 --year=2020 --format=TV
''');
}

// ─── Matching helpers ─────────────────────────────────────────────────────────

AnimeFormat _parseAnimeFormat(String? format) {
  if (format == null) return AnimeFormat.unknown;
  return switch (format.toUpperCase()) {
    'TV' => AnimeFormat.tv,
    'MOVIE' => AnimeFormat.movie,
    'OVA' => AnimeFormat.ova,
    'ONA' => AnimeFormat.ona,
    'SPECIAL' => AnimeFormat.special,
    _ => AnimeFormat.unknown,
  };
}

CanonicalSeries _canonicalFromConfig(_Config config) {
  return CanonicalSeries(
    canonicalId: 'query:${config.query}',
    anilistId: 0,
    primaryTitle: config.query,
    aliases: config.matchingAliases,
    format: _parseAnimeFormat(config.matchingFormat),
    releaseYear: config.matchingYear,
    episodeCount: config.matchingEpisodes,
  );
}

Future<CanonicalSeries> _buildCanonical(_Config config) async {
  if (config.anilistId == null) return _canonicalFromConfig(config);

  final httpClient = http.Client();
  try {
    final anilistClient = HttpAnilistGraphqlClient(httpClient: httpClient);
    final gateway = GraphqlAnilistMetadataGateway(client: anilistClient);
    final repository = AnilistAnimeCatalogRepository(gateway: gateway);
    final result = await repository.fetchAnimeDetail(config.anilistId!);
    return result.fold(
      onSuccess: CanonicalSeries.fromAnimeDetail,
      onFailure: (err) {
        print(
          '${_yellow}Warning: AniList fetch failed for ID ${config.anilistId} '
          '(${err.message}). Using query as canonical.$_reset',
        );
        return _canonicalFromConfig(config);
      },
    );
  } finally {
    httpClient.close();
  }
}

// ─── Source building ─────────────────────────────────────────────────────────

Map<String, SourcePlugin> _buildSources(_Config config) {
  final all = <String, SourcePlugin>{
    'JKAnime': JkAnimeSourcePlugin(),
    'AnimeFlv': AnimeFlvSourcePlugin(),
    'AnimeAV1': AnimeAv1SourcePlugin(),
    'AnimeNexus': AnimeNexusSourcePlugin(),
  };

  if (config.sourceFilter != null) {
    final key = all.keys.firstWhere(
      (k) => k.toLowerCase() == config.sourceFilter!.toLowerCase(),
      orElse: () => '',
    );
    if (key.isEmpty) {
      print(
          '${_red}Unknown source "${config.sourceFilter}". Available: ${all.keys.join(", ")}$_reset');
      exit(1);
    }
    return {key: all[key]!};
  }

  return all;
}

// ─── Phase 1: Source collection ──────────────────────────────────────────────

Future<_SourceResult> _collectFromSource(
  String sourceName,
  SourcePlugin plugin,
  _Config config,
  CanonicalSeries canonical,
) async {
  final result = _SourceResult(
    sourceName: sourceName,
    pluginId: plugin.manifest.id,
  );

  if (!config.jsonOutput) {
    print('$_bold═══ Source: $sourceName ═══$_reset');
  }

  // Search
  try {
    if (!config.jsonOutput) {
      stdout.write('  ${_cyan}Search$_reset "$_dim${config.query}$_reset"...');
    }

    final sw = Stopwatch()..start();
    final searchResult = await plugin.search(
      SourceSearchQuery(query: config.query),
    );
    sw.stop();
    result.searchTimeMs = sw.elapsedMilliseconds;

    final matches = searchResult.fold(
      onSuccess: (m) => m,
      onFailure: (e) {
        result.error = 'Search failed: ${e.message}';
        return <SourceAnimeMatch>[];
      },
    );

    if (matches.isEmpty) {
      result.error ??= 'No search results';
      if (!config.jsonOutput) {
        print(' ${_yellow}no results$_reset ${_dim}(${sw.elapsedMilliseconds}ms)$_reset');
      }
      return result;
    }

    result.matchCandidateCount = matches.length;

    // ── Entity resolution via kumoriya_matching ──────────────────────────
    const fpBuilder = SeriesFingerprintBuilder();
    final queryFp = fpBuilder.fromCanonical(canonical);
    final sourceFingerprints = matches
        .map(
          (m) => fpBuilder.fromSource(
            SourceSeriesRecord.fromSourceAnimeMatch(
              sourceId: plugin.manifest.id,
              match: m,
            ),
          ),
        )
        .toList();
    final decision = SeriesEntityResolver<SourceSeriesRecord>(
      candidateIndex: SeriesCandidateIndex<SourceSeriesRecord>(
        sourceFingerprints,
      ),
    ).resolve(queryFp);

    result.matchScore = decision.bestScore;
    result.matchReasons = decision.reasons
        .map(
          (r) =>
              '${r.code.name}(${r.impact >= 0 ? "+" : ""}${r.impact.toStringAsFixed(1)})',
        )
        .toList();

    final SourceAnimeMatch match;
    if (decision.bestCandidate != null &&
        decision.verdict != SeriesDecisionVerdict.reject) {
      final bestRecord = decision.bestCandidate!;
      match = matches.firstWhere(
        (m) => m.sourceId == bestRecord.sourceSeriesId,
        orElse: () => matches.first,
      );
      result.matchVerdict = decision.verdict.name; // autoMatch | reviewNeeded
    } else {
      match = matches.first;
      result.matchVerdict = 'fallback';
    }

    result.matchedTitle = match.title;
    result.matchedSourceId = match.sourceId;

    if (!config.jsonOutput) {
      final verdictColor = switch (result.matchVerdict!) {
        'autoMatch' => _green,
        'reviewNeeded' => _yellow,
        _ => _dim,
      };
      final scoreStr = result.matchScore != null
          ? ' ${_dim}score=${result.matchScore!.toStringAsFixed(1)}$_reset'
          : '';
      final candidatesStr =
          ' ${_dim}(${matches.length} candidate${matches.length == 1 ? "" : "s"})$_reset';
      print(
        ' ${_green}found "$_reset${match.title}$_green"$_reset '
        '$verdictColor${result.matchVerdict}$_reset$scoreStr$candidatesStr '
        '${_dim}(${sw.elapsedMilliseconds}ms)$_reset',
      );
    }
  } catch (e, stack) {
    result.error = 'Search exception: $e';
    result.searchTimeMs = 0;
    if (!config.jsonOutput) {
      print(' ${_red}EXCEPTION: $e$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
    return result;
  }

  // Episodes
  try {
    if (!config.jsonOutput) {
      stdout.write('  ${_cyan}Episodes$_reset...');
    }

    final sw = Stopwatch()..start();
    final episodesResult = await plugin.getEpisodes(result.matchedSourceId!);
    sw.stop();
    result.episodeTimeMs = sw.elapsedMilliseconds;

    final episodes = episodesResult.fold(
      onSuccess: (e) => e,
      onFailure: (e) {
        result.error = 'Episode listing failed: ${e.message}';
        return <SourceEpisode>[];
      },
    );

    result.episodeCount = episodes.length;

    if (episodes.isEmpty) {
      result.error ??= 'No episodes found';
      if (!config.jsonOutput) {
        print(' ${_yellow}none found$_reset ${_dim}(${sw.elapsedMilliseconds}ms)$_reset');
      }
      return result;
    }

    // Find target episode
    final target = episodes.cast<SourceEpisode?>().firstWhere(
          (e) => e!.number == config.targetEpisode,
          orElse: () => episodes.first,
        );

    if (target == null) {
      result.error = 'Episode ${config.targetEpisode} not found';
      if (!config.jsonOutput) {
        print(' ${_yellow}ep ${config.targetEpisode} not found$_reset');
      }
      return result;
    }

    if (!config.jsonOutput) {
      print(
          ' ${_green}${episodes.length} episodes$_reset, using ep ${target.number} ${_dim}(${sw.elapsedMilliseconds}ms)$_reset');
    }

    // Server links
    if (!config.jsonOutput) {
      stdout.write('  ${_cyan}Server links$_reset...');
    }

    final sw2 = Stopwatch()..start();
    final linksResult = await plugin.getEpisodeServerLinks(target);
    sw2.stop();
    result.serverLinksTimeMs = sw2.elapsedMilliseconds;

    final links = linksResult.fold(
      onSuccess: (l) => l,
      onFailure: (e) {
        result.error = 'Server links failed: ${e.message}';
        return <SourceServerLink>[];
      },
    );

    result.serverLinkCount = links.length;
    result.serverLinks.addAll(links);

    if (!config.jsonOutput) {
      print(
          ' ${_green}${links.length} links$_reset ${_dim}(${sw2.elapsedMilliseconds}ms)$_reset');
      if (config.verbose) {
        for (final link in links) {
          print(
              '    ${_dim}• ${link.serverName} [${link.detectedHost ?? link.initialUrl.host}] ${link.language ?? ""} ${link.linkType.name}$_reset');
          print('      ${_dim}${link.initialUrl}$_reset');
        }
      }
    }
  } catch (e, stack) {
    result.error = 'Episode/links exception: $e';
    if (!config.jsonOutput) {
      print(' ${_red}EXCEPTION: $e$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
  }

  if (!config.jsonOutput) print('');
  return result;
}

// ─── Phase 2: Resolution ────────────────────────────────────────────────────

Future<void> _resolveServerLink(
  _ServerLinkResult result,
  List<ResolverPlugin> resolvers,
  _Config config,
) async {
  final url = result.serverLink.initialUrl;
  final serverName = result.serverLink.serverName;
  final host = result.serverLink.detectedHost ?? url.host;

  // Find resolver
  ResolverPlugin? resolver;
  if (config.resolverFilter != null) {
    resolver = resolvers.cast<ResolverPlugin?>().firstWhere(
          (r) =>
              r!.manifest.displayName
                  .toLowerCase()
                  .contains(config.resolverFilter!.toLowerCase()) ||
              r.manifest.id
                  .toLowerCase()
                  .contains(config.resolverFilter!.toLowerCase()),
          orElse: () => null,
        );
    if (resolver != null && !resolver.supports(url)) {
      result.resolveError = 'Filtered resolver does not support this URL';
      result.resolveErrorCode = 'filter.mismatch';
      if (!config.jsonOutput) {
        print(
            '  ${_dim}[$_reset${result.sourceName}${_dim}]$_reset $serverName ($host) → ${_yellow}filtered resolver mismatch$_reset');
      }
      return;
    }
  } else {
    resolver = findResolverFor(url, resolvers);
  }

  if (resolver == null) {
    result.resolveError = 'No resolver supports host: $host';
    result.resolveErrorCode = 'resolver.not_found';
    if (!config.jsonOutput) {
      print(
          '  ${_dim}[$_reset${result.sourceName}${_dim}]$_reset $serverName ($host) → ${_yellow}NO RESOLVER$_reset');
    }
    return;
  }

  result.resolverName = resolver.manifest.displayName;
  result.resolverId = resolver.manifest.id;
  result.resolverPriority = resolver.priority;

  if (!config.jsonOutput) {
    stdout.write(
        '  ${_dim}[$_reset${result.sourceName}${_dim}]$_reset $serverName → ${resolver.manifest.displayName}...');
  }

  final sw = Stopwatch()..start();
  try {
    final resolveResult = await resolver
        .resolve(url)
        .timeout(Duration(seconds: config.timeoutSeconds));
    sw.stop();
    result.resolveTimeMs = sw.elapsedMilliseconds;

    resolveResult.fold(
      onSuccess: (resolved) {
        result.resolveSuccess = true;
        result.streamCount = resolved.streams.length;
        result.subtitleCount = resolved.externalSubtitles.length;

        for (final s in resolved.streams) {
          result.resolvedStreams.add(_StreamInfo(
            url: s.url.toString(),
            qualityLabel: s.qualityLabel,
            mimeType: s.mimeType,
            isHls: s.isHls,
            headers: s.headers,
          ));
        }

        if (!config.jsonOutput) {
          final streamDesc = resolved.streams
              .map((s) =>
                  '${s.qualityLabel ?? "?"}${s.isHls ? " [HLS]" : ""}')
              .join(', ');
          print(
              ' ${_green}✓$_reset ${resolved.streams.length} streams ($streamDesc) ${_dim}${sw.elapsedMilliseconds}ms$_reset');
          if (config.verbose) {
            for (final s in resolved.streams) {
              print('      ${_dim}${s.url}$_reset');
              if (s.headers.isNotEmpty) {
                print(
                    '      ${_dim}headers: ${s.headers.entries.map((e) => '${e.key}: ${e.value.substring(0, e.value.length.clamp(0, 60))}').join(', ')}$_reset');
              }
            }
          }
        }
      },
      onFailure: (error) {
        result.resolveError = error.message;
        result.resolveErrorCode = error.code;

        if (!config.jsonOutput) {
          print(
              ' ${_red}✗ [${error.code}] ${error.message}$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
        }
      },
    );
  } on TimeoutException {
    sw.stop();
    result.resolveTimeMs = sw.elapsedMilliseconds;
    result.resolveError = 'Timeout after ${config.timeoutSeconds}s';
    result.resolveErrorCode = 'resolver.timeout';

    if (!config.jsonOutput) {
      print(
          ' ${_red}✗ TIMEOUT (${config.timeoutSeconds}s)$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
    }
  } catch (e, stack) {
    sw.stop();
    result.resolveTimeMs = sw.elapsedMilliseconds;
    result.resolveError = e.toString();
    result.resolveErrorCode = 'resolver.exception';

    if (!config.jsonOutput) {
      print(
          ' ${_red}✗ EXCEPTION: $e$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
  }
}

// ─── Phase 3: Download probe / full download ─────────────────────────────────

const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> _probeOrDownload(
  _ServerLinkResult result,
  http.Client httpClient,
  _Config config,
) async {
  // Use the first (best) resolved stream
  final stream = result.resolvedStreams.first;
  final serverName = result.serverLink.serverName;

  if (!config.jsonOutput) {
    stdout.write(
        '  ${_dim}[$_reset${result.sourceName}${_dim}]$_reset $serverName ${_dim}(${stream.qualityLabel ?? "?"}${stream.isHls ? " HLS" : ""})$_reset → ');
  }

  if (stream.isHls) {
    await _probeHls(result, stream, httpClient, config);
  } else {
    await _probeDirect(result, stream, httpClient, config);
  }
}

Future<void> _probeHls(
  _ServerLinkResult result,
  _StreamInfo stream,
  http.Client httpClient,
  _Config config,
) async {
  result.downloadProbed = true;
  final url = Uri.parse(stream.url);

  final sw = Stopwatch()..start();
  try {
    final headers = <String, String>{
      'User-Agent': _browserUserAgent,
      ...stream.headers,
    };

    final request = http.Request('GET', url);
    request.headers.addAll(headers);

    final response = await httpClient.send(request).timeout(
          const Duration(seconds: 15),
        );
    final body = await response.stream.bytesToString().timeout(
          const Duration(seconds: 15),
        );
    sw.stop();
    result.probeTimeMs = sw.elapsedMilliseconds;
    result.probeStatusCode = response.statusCode;
    result.probeContentType = response.headers['content-type'];
    result.probeResponseHeaders = Map.from(response.headers);
    result.probeBytesReceived = body.length;

    if (response.statusCode >= 200 && response.statusCode < 400) {
      // Check if it's a valid M3U8 playlist
      final isValidM3u8 = body.contains('#EXTM3U') || body.contains('#EXT-X-');
      if (isValidM3u8) {
        // Count segments
        final segmentLines = body
            .split('\n')
            .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
            .length;
        result.probeSuccess = true;

        // Try to estimate total size from bandwidth/duration
        if (!config.jsonOutput) {
          print(
              '${_green}✓ HLS playlist OK$_reset ($segmentLines segments, ${body.length} bytes) ${_dim}${sw.elapsedMilliseconds}ms$_reset');
        }

        // If full download, try to download first segment
        if (config.fullDownload) {
          await _downloadHlsFull(result, stream, body, httpClient, config);
        }
      } else {
        result.probeSuccess = false;
        result.probeError = 'Response is not a valid M3U8 playlist';
        if (!config.jsonOutput) {
          final preview = body.substring(0, body.length.clamp(0, 200));
          print(
              '${_red}✗ Invalid M3U8$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
          if (config.verbose) {
            print('      ${_dim}Response preview: $preview$_reset');
          }
        }
      }
    } else {
      result.probeSuccess = false;
      result.probeError = 'HTTP ${response.statusCode}';
      if (!config.jsonOutput) {
        print(
            '${_red}✗ HTTP ${response.statusCode}$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
        if (config.verbose && body.isNotEmpty) {
          final preview = body.substring(0, body.length.clamp(0, 200));
          print('      ${_dim}Body: $preview$_reset');
        }
      }
    }
  } catch (e, stack) {
    sw.stop();
    result.probeTimeMs = sw.elapsedMilliseconds;
    result.probeSuccess = false;
    result.probeError = e.toString();
    if (!config.jsonOutput) {
      print(
          '${_red}✗ $e$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
  }
}

Future<void> _probeDirect(
  _ServerLinkResult result,
  _StreamInfo stream,
  http.Client httpClient,
  _Config config,
) async {
  result.downloadProbed = true;
  final url = Uri.parse(stream.url);

  final sw = Stopwatch()..start();
  try {
    final headers = <String, String>{
      'User-Agent': _browserUserAgent,
      ...stream.headers,
    };

    // HEAD probe first for metadata
    final headRequest = http.Request('HEAD', url);
    headRequest.headers.addAll(headers);

    final headResponse = await httpClient.send(headRequest).timeout(
          const Duration(seconds: 10),
        );
    await headResponse.stream.drain<void>();

    result.probeStatusCode = headResponse.statusCode;
    result.probeContentType = headResponse.headers['content-type'];
    result.probeResponseHeaders = Map.from(headResponse.headers);

    final contentLength =
        int.tryParse(headResponse.headers['content-length'] ?? '');
    result.probeTotalBytes = contentLength;

    final acceptRanges = headResponse.headers['accept-ranges'];
    result.probeSupportsRanges =
        acceptRanges != null && acceptRanges.toLowerCase() != 'none';

    if (headResponse.statusCode >= 200 && headResponse.statusCode < 400) {
      // Now do a partial GET to verify data flows
      final rangeEnd = (config.probeBytes - 1).clamp(0, (contentLength ?? config.probeBytes) - 1);

      final getRequest = http.Request('GET', url);
      getRequest.headers.addAll(headers);
      if (result.probeSupportsRanges) {
        getRequest.headers['Range'] = 'bytes=0-$rangeEnd';
      }

      final getResponse = await httpClient.send(getRequest).timeout(
            const Duration(seconds: 15),
          );

      int received = 0;
      await for (final chunk in getResponse.stream.timeout(
        const Duration(seconds: 30),
      )) {
        received += chunk.length;
        // In probe mode, bail after enough bytes
        if (!config.fullDownload && received >= config.probeBytes) break;
      }

      sw.stop();
      result.probeTimeMs = sw.elapsedMilliseconds;
      result.probeBytesReceived = received;
      result.probeSuccess = received > 0;

      if (!config.jsonOutput) {
        final sizeStr = _formatBytes(received);
        final totalStr = contentLength != null
            ? '/${_formatBytes(contentLength)}'
            : '';
        final rangeStr =
            result.probeSupportsRanges ? ' [ranges ✓]' : ' [no ranges]';
        print(
            '${_green}✓ $sizeStr$totalStr$_reset$rangeStr ${_dim}${sw.elapsedMilliseconds}ms$_reset');
      }

      // Full download if requested
      if (config.fullDownload && result.probeSuccess) {
        await _downloadDirectFull(result, stream, httpClient, config);
      }
    } else {
      sw.stop();
      result.probeTimeMs = sw.elapsedMilliseconds;
      result.probeSuccess = false;
      result.probeError = 'HTTP ${headResponse.statusCode}';

      if (!config.jsonOutput) {
        print(
            '${_red}✗ HTTP ${headResponse.statusCode}$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
        if (config.verbose) {
          print(
              '      ${_dim}Headers: ${headResponse.headers}$_reset');
        }
      }
    }
  } catch (e, stack) {
    sw.stop();
    result.probeTimeMs = sw.elapsedMilliseconds;
    result.probeSuccess = false;
    result.probeError = e.toString();

    if (!config.jsonOutput) {
      print(
          '${_red}✗ $e$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
  }
}

// ─── Full download helpers ───────────────────────────────────────────────────

Future<void> _downloadHlsFull(
  _ServerLinkResult result,
  _StreamInfo stream,
  String playlistBody,
  http.Client httpClient,
  _Config config,
) async {
  result.fullDownloaded = true;
  final baseUrl = Uri.parse(stream.url);
  final headers = <String, String>{
    'User-Agent': _browserUserAgent,
    ...stream.headers,
  };

  final dir = Directory(config.downloadDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final safeName = result.serverLink.serverName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final outPath =
      '${config.downloadDir}/${result.sourceName}_${safeName}_hls.ts';

  if (!config.jsonOutput) {
    stdout.write(
        '    ${_magenta}Downloading HLS$_reset to ${_dim}$outPath$_reset...');
  }

  final sw = Stopwatch()..start();
  try {
    // Parse segment URLs from playlist
    final lines = playlistBody.split('\n');
    final segmentUrls = <Uri>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final segUrl = baseUrl.resolve(trimmed);
      segmentUrls.add(segUrl);
    }

    final outFile = File(outPath);
    final sink = outFile.openWrite();
    var totalBytes = 0;
    var segsDone = 0;

    for (final segUrl in segmentUrls) {
      final req = http.Request('GET', segUrl);
      req.headers.addAll(headers);

      final resp = await httpClient.send(req).timeout(
            const Duration(seconds: 30),
          );

      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          totalBytes += chunk.length;
        }
        segsDone++;
      } else {
        // Log segment failure but continue
        if (config.verbose && !config.jsonOutput) {
          print(
              '\n      ${_yellow}Segment ${segsDone + 1} HTTP ${resp.statusCode}$_reset');
        }
        await resp.stream.drain<void>();
        segsDone++;
      }
    }

    await sink.flush();
    await sink.close();
    sw.stop();

    result.downloadTimeMs = sw.elapsedMilliseconds;
    result.downloadBytesReceived = totalBytes;
    result.downloadPath = outPath;
    result.downloadSuccess = totalBytes > 0;

    if (!config.jsonOutput) {
      print(
          ' ${_green}✓ ${_formatBytes(totalBytes)}$_reset ($segsDone/${segmentUrls.length} segs) ${_dim}${sw.elapsedMilliseconds}ms$_reset');
    }
  } catch (e, stack) {
    sw.stop();
    result.downloadTimeMs = sw.elapsedMilliseconds;
    result.downloadSuccess = false;
    result.downloadError = e.toString();

    if (!config.jsonOutput) {
      print(' ${_red}✗ $e$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
  }
}

Future<void> _downloadDirectFull(
  _ServerLinkResult result,
  _StreamInfo stream,
  http.Client httpClient,
  _Config config,
) async {
  result.fullDownloaded = true;
  final url = Uri.parse(stream.url);
  final headers = <String, String>{
    'User-Agent': _browserUserAgent,
    ...stream.headers,
  };

  final dir = Directory(config.downloadDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final safeName = result.serverLink.serverName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  final ext = stream.isHls ? '.ts' : '.mp4';
  final outPath =
      '${config.downloadDir}/${result.sourceName}_${safeName}$ext';

  if (!config.jsonOutput) {
    stdout.write(
        '    ${_magenta}Downloading$_reset to ${_dim}$outPath$_reset...');
  }

  final sw = Stopwatch()..start();
  try {
    final req = http.Request('GET', url);
    req.headers.addAll(headers);

    final resp = await httpClient.send(req).timeout(
          const Duration(seconds: 15),
        );

    if (resp.statusCode >= 200 && resp.statusCode < 400) {
      final outFile = File(outPath);
      final sink = outFile.openWrite();
      var totalBytes = 0;

      await for (final chunk in resp.stream.timeout(
        const Duration(minutes: 5),
      )) {
        sink.add(chunk);
        totalBytes += chunk.length;
      }

      await sink.flush();
      await sink.close();
      sw.stop();

      result.downloadTimeMs = sw.elapsedMilliseconds;
      result.downloadBytesReceived = totalBytes;
      result.downloadPath = outPath;
      result.downloadSuccess = totalBytes > 0;

      if (!config.jsonOutput) {
        print(
            ' ${_green}✓ ${_formatBytes(totalBytes)}$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
      }
    } else {
      sw.stop();
      result.downloadTimeMs = sw.elapsedMilliseconds;
      result.downloadSuccess = false;
      result.downloadError = 'HTTP ${resp.statusCode}';
      await resp.stream.drain<void>();

      if (!config.jsonOutput) {
        print(
            ' ${_red}✗ HTTP ${resp.statusCode}$_reset ${_dim}${sw.elapsedMilliseconds}ms$_reset');
      }
    }
  } catch (e, stack) {
    sw.stop();
    result.downloadTimeMs = sw.elapsedMilliseconds;
    result.downloadSuccess = false;
    result.downloadError = e.toString();

    if (!config.jsonOutput) {
      print(' ${_red}✗ $e$_reset');
      if (config.verbose) print('$_dim$stack$_reset');
    }
  }
}

// ─── Phase 4: Summary + Report ──────────────────────────────────────────────

void _printHeader(_Config config) {
  print('');
  print('$_bold═══════════════════════════════════════════════════════$_reset');
  print('$_bold  Kumoriya Download Pipeline Playground$_reset');
  print('$_bold═══════════════════════════════════════════════════════$_reset');
  print('${_dim}Query:    "${config.query}"$_reset');
  print('${_dim}Episode:  ${config.targetEpisode}$_reset');
  if (config.sourceFilter != null) {
    print('${_dim}Source:   ${config.sourceFilter}$_reset');
  }
  if (config.resolverFilter != null) {
    print('${_dim}Resolver: ${config.resolverFilter}$_reset');
  }
  print(
      '${_dim}Mode:     ${config.fullDownload ? "Full download" : "Probe (${_formatBytes(config.probeBytes)})"}$_reset');
  print(
      '${_dim}Timeout:  ${config.timeoutSeconds}s$_reset');
  print('');
  print('$_bold═══ Phase 1: Source Collection ═══$_reset');
  print('');
}

void _printSummary(
  List<_SourceResult> sourceResults,
  List<_ServerLinkResult> allResults,
  Stopwatch globalSw,
) {
  print('');
  print(
      '$_bold═══════════════════════════════════════════════════════$_reset');
  print('$_bold  Pipeline Summary$_reset');
  print(
      '$_bold═══════════════════════════════════════════════════════$_reset');
  print('');

  // Source summary
  print('$_bold── Sources ──$_reset');
  for (final s in sourceResults) {
    final status = s.error != null ? '$_red✗' : '$_green✓';
    print(
        '  $status ${s.sourceName}$_reset: ${s.serverLinkCount} links '
        '${_dim}(search: ${s.searchTimeMs}ms, eps: ${s.episodeTimeMs}ms, links: ${s.serverLinksTimeMs}ms)$_reset');
    if (s.error != null) {
      print('    ${_red}${s.error}$_reset');
    }
  }

  // Resolution summary
  print('');
  print('$_bold── Resolution ──$_reset');
  final resolved = allResults.where((r) => r.resolveSuccess).toList();
  final resolveFailed = allResults
      .where((r) => !r.resolveSuccess && r.resolverName != null)
      .toList();
  final noResolver = allResults
      .where((r) => r.resolveErrorCode == 'resolver.not_found')
      .toList();

  print(
      '  Total server links:  ${allResults.length}');
  print(
      '  ${_green}Resolved OK:         ${resolved.length}$_reset');
  print(
      '  ${_red}Resolve failed:      ${resolveFailed.length}$_reset');
  print(
      '  ${_yellow}No resolver:         ${noResolver.length}$_reset');

  if (noResolver.isNotEmpty) {
    final hosts = noResolver
        .map((r) => r.serverLink.detectedHost ?? r.serverLink.initialUrl.host)
        .toSet();
    print('  ${_dim}Unhandled hosts: ${hosts.join(", ")}$_reset');
  }

  if (resolveFailed.isNotEmpty) {
    print('');
    print('  ${_bold}Failed resolvers:$_reset');
    for (final f in resolveFailed) {
      print(
          '    ${_red}✗$_reset ${f.resolverName} ← ${f.serverLink.serverName} [${f.resolveErrorCode}] ${f.resolveError}');
    }
  }

  // Download summary
  print('');
  print('$_bold── Downloads ──$_reset');
  final probed = allResults.where((r) => r.downloadProbed).toList();
  final probeOk = probed.where((r) => r.probeSuccess).toList();
  final probeFail = probed.where((r) => !r.probeSuccess).toList();

  print(
      '  Streams probed:     ${probed.length}');
  print(
      '  ${_green}Probe success:       ${probeOk.length}$_reset');
  print(
      '  ${_red}Probe failed:        ${probeFail.length}$_reset');

  if (probeFail.isNotEmpty) {
    print('');
    print('  ${_bold}Failed probes:$_reset');
    for (final f in probeFail) {
      print(
          '    ${_red}✗$_reset ${f.serverLink.serverName} (${f.resolverName}) HTTP ${f.probeStatusCode ?? "?"}: ${f.probeError}');
    }
  }

  // Per-resolver scorecard
  print('');
  print('$_bold── Resolver Scorecard ──$_reset');
  final byResolver = <String, List<_ServerLinkResult>>{};
  for (final r in allResults) {
    final key = r.resolverName ?? '(no resolver)';
    byResolver.putIfAbsent(key, () => []).add(r);
  }

  print(
      '  ${'Resolver'.padRight(25)} ${'Resolve'.padRight(10)} ${'Probe'.padRight(10)} ${'Avg Time'.padRight(10)}');
  print('  ${_dim}${'─' * 60}$_reset');

  for (final entry in byResolver.entries) {
    final name = entry.key.padRight(25);
    final items = entry.value;
    final resolveOkCount = items.where((r) => r.resolveSuccess).length;
    final probeOkCount = items.where((r) => r.probeSuccess).length;
    final resolveTimes =
        items.where((r) => r.resolveTimeMs > 0).map((r) => r.resolveTimeMs);
    final avgTime = resolveTimes.isNotEmpty
        ? '${(resolveTimes.reduce((a, b) => a + b) / resolveTimes.length).round()}ms'
        : '-';

    final resolveStr =
        '$resolveOkCount/${items.length}'.padRight(10);
    final probeStr = '$probeOkCount/${items.length}'.padRight(10);

    final color = resolveOkCount == items.length && probeOkCount > 0
        ? _green
        : (resolveOkCount > 0 ? _yellow : _red);
    print('  $color$name$_reset $resolveStr $probeStr $avgTime');
  }

  print('');
  print(
      '${_dim}Total time: ${globalSw.elapsedMilliseconds}ms$_reset');
  print('');
}

void _writeReport(
  _Config config,
  List<_SourceResult> sourceResults,
  List<_ServerLinkResult> allResults,
  Stopwatch globalSw,
) {
  final report = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'query': config.query,
    'targetEpisode': config.targetEpisode,
    'sourceFilter': config.sourceFilter,
    'resolverFilter': config.resolverFilter,
    'mode': config.fullDownload ? 'full_download' : 'probe',
    'probeBytes': config.probeBytes,
    'timeoutSeconds': config.timeoutSeconds,
    'totalTimeMs': globalSw.elapsedMilliseconds,
    'matchingConfig': {
      'year': config.matchingYear,
      'format': config.matchingFormat,
      'episodes': config.matchingEpisodes,
      'aliases': config.matchingAliases,
      'anilistId': config.anilistId,
    },
    'sources': sourceResults
        .map((s) => {
              'name': s.sourceName,
              'pluginId': s.pluginId,
              'matchedTitle': s.matchedTitle,
              'matchedSourceId': s.matchedSourceId,
              'matchVerdict': s.matchVerdict,
              'matchScore': s.matchScore,
              'matchReasons': s.matchReasons,
              'matchCandidateCount': s.matchCandidateCount,
              'searchTimeMs': s.searchTimeMs,
              'episodeTimeMs': s.episodeTimeMs,
              'serverLinksTimeMs': s.serverLinksTimeMs,
              'episodeCount': s.episodeCount,
              'serverLinkCount': s.serverLinkCount,
              'error': s.error,
            })
        .toList(),
    'serverLinks': allResults.map((r) => r.toJson()).toList(),
    'summary': {
      'totalLinks': allResults.length,
      'resolvedOk': allResults.where((r) => r.resolveSuccess).length,
      'resolveFailed': allResults
          .where((r) => !r.resolveSuccess && r.resolverName != null)
          .length,
      'noResolver': allResults
          .where((r) => r.resolveErrorCode == 'resolver.not_found')
          .length,
      'probeOk': allResults.where((r) => r.probeSuccess).length,
      'probeFailed':
          allResults.where((r) => r.downloadProbed && !r.probeSuccess).length,
      'unhandledHosts': allResults
          .where((r) => r.resolveErrorCode == 'resolver.not_found')
          .map((r) =>
              r.serverLink.detectedHost ?? r.serverLink.initialUrl.host)
          .toSet()
          .toList(),
    },
  };

  final jsonStr = const JsonEncoder.withIndent('  ').convert(report);

  if (config.jsonOutput) {
    print(jsonStr);
  }

  // Always write to file if --output specified
  final outputPath = config.outputFile;
  if (outputPath != null) {
    File(outputPath).writeAsStringSync(jsonStr);
    if (!config.jsonOutput) {
      print('${_cyan}Report written to: $outputPath$_reset');
    }
  }

  // Auto-write a timestamped report even without --output
  if (outputPath == null) {
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final autoPath = 'download_playground_report_$ts.json';
    File(autoPath).writeAsStringSync(jsonStr);
    if (!config.jsonOutput) {
      print('${_cyan}Report auto-saved: $autoPath$_reset');
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
