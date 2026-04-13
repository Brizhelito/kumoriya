// ignore_for_file: avoid_print
/// Resolver playground: tests Zilla HLS resolution and download-path headers
/// to diagnose why the player resolves fine but the downloader times out.
///
/// Usage:
///   dart run tool/zilla_resolver_playground.dart [animeav1_source_id] [episode_index]
///
/// Example:
///   dart run tool/zilla_resolver_playground.dart jujutsu-kaisen 0
///
/// If no args: searches "Jujutsu Kaisen", picks first result, first episode.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_zilla/kumoriya_resolver_zilla.dart';
import 'package:kumoriya_source_animeav1/kumoriya_source_animeav1.dart';

import 'package:kumoriya_app/src/features/anime_catalog/application/services/resolver_registry.dart';
import 'package:kumoriya_app/src/features/anime_catalog/application/use_cases/resolve_source_server_link_use_case.dart';

const _browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

Future<void> main(List<String> args) async {
  final source = AnimeAv1SourcePlugin();
  final zillaResolver = ZillaResolverPlugin();
  final registry = ResolverRegistry(
    resolvers: <ResolverPlugin>[zillaResolver],
  );
  final resolveUseCase = ResolveSourceServerLinkUseCase(registry: registry);

  // ── 1. Get an episode with Zilla server links ────────────────────────
  String? sourceId;
  int episodeIndex = 0;

  if (args.isNotEmpty) {
    sourceId = args.first;
    if (args.length > 1) episodeIndex = int.tryParse(args[1]) ?? 0;
  } else {
    print('─── Searching AnimeAV1 for "Jujutsu Kaisen" ───');
    final searchResult = await source.search(
      const SourceSearchQuery(query: 'Jujutsu Kaisen'),
    );
    if (searchResult.isFailure) {
      print('Search failed: $searchResult');
      exit(1);
    }
    final matches =
        (searchResult as Success<List<SourceAnimeMatch>, KumoriyaError>).value;
    if (matches.isEmpty) {
      print('No results found');
      exit(1);
    }
    sourceId = matches.first.sourceId;
    print('Found: ${matches.first.title} (sourceId=$sourceId)');
  }

  print('\n─── Getting episodes for sourceId=$sourceId ───');
  final episodesResult = await source.getEpisodes(sourceId!);
  if (episodesResult.isFailure) {
    print('getEpisodes failed: $episodesResult');
    exit(1);
  }
  final episodes =
      (episodesResult as Success<List<SourceEpisode>, KumoriyaError>).value;
  if (episodes.isEmpty || episodeIndex >= episodes.length) {
    print('No episodes or index out of range (total=${episodes.length})');
    exit(1);
  }
  final episode = episodes[episodeIndex];
  print(
    'Episode: ${episode.sourceEpisodeId} '
    '(number=${episode.number})',
  );

  print('\n─── Getting server links ───');
  final linksResult = await source.getEpisodeServerLinks(episode);
  if (linksResult.isFailure) {
    print('getEpisodeServerLinks failed: $linksResult');
    exit(1);
  }
  final links =
      (linksResult as Success<List<SourceServerLink>, KumoriyaError>).value;

  print('Found ${links.length} servers:');
  for (final link in links) {
    print('  - ${link.serverName}: ${link.initialUrl}');
  }

  // Find Zilla links (server name usually "HLS" on AnimeAV1)
  final zillaLinks = links.where(
    (link) =>
        link.initialUrl.host.toLowerCase().contains('zilla-networks') ||
        link.serverName.toLowerCase() == 'hls',
  );

  if (zillaLinks.isEmpty) {
    print('\n⚠ No Zilla/HLS links found for this episode');
    exit(1);
  }

  for (final zillaLink in zillaLinks) {
    print(
      '\n══════════════════════════════════════════════════════════════'
      '\n  Testing: ${zillaLink.serverName} → ${zillaLink.initialUrl}'
      '\n══════════════════════════════════════════════════════════════',
    );

    // ── 2. Resolve via ResolveSourceServerLinkUseCase (same as app) ──
    print('\n─── Step 1: Resolver (same as app) ───');
    final sw1 = Stopwatch()..start();
    final resolveResult = await resolveUseCase.call(zillaLink);
    sw1.stop();

    if (resolveResult.isFailure) {
      print('✗ Resolve FAILED in ${sw1.elapsedMilliseconds}ms: '
          '$resolveResult');
      continue;
    }

    final resolved = resolveResult.fold(
      onSuccess: (v) => v,
      onFailure: (_) => null,
    )!;
    final stream = resolved.streams.first;

    print('✓ Resolved in ${sw1.elapsedMilliseconds}ms');
    print('  url: ${stream.url}');
    print('  isHls: ${stream.isHls}');
    print('  quality: ${stream.qualityLabel}');
    print('  headers: ${stream.headers}');

    // ── 3. Re-fetch playlist like the HLS downloader does ────────────
    // This is the EXACT same code path as _fetchPlaylist in
    // hls_segment_downloader.dart — same headers, same approach.
    print('\n─── Step 2: Re-fetch playlist (downloader-style headers) ───');
    await _testFetch(
      label: 'downloader-style',
      url: stream.url,
      headers: <String, String>{
        ...stream.headers,
        'User-Agent': _browserUserAgent,
        'Accept-Encoding': 'identity',
      },
      timeout: const Duration(seconds: 15),
    );

    // ── 4. Fetch with ONLY resolver headers (no UA, no Accept-Encoding)
    print('\n─── Step 3: Re-fetch playlist (resolver-style, minimal) ───');
    await _testFetch(
      label: 'resolver-style',
      url: stream.url,
      headers: stream.headers,
      timeout: const Duration(seconds: 15),
    );

    // ── 5. Fetch with no headers at all ──────────────────────────────
    print('\n─── Step 4: Re-fetch playlist (no headers) ───');
    await _testFetch(
      label: 'no-headers',
      url: stream.url,
      headers: const <String, String>{},
      timeout: const Duration(seconds: 15),
    );

    // ── 6. Fetch with only Accept-Encoding ───────────────────────────
    print('\n─── Step 5: Re-fetch with Accept-Encoding only ───');
    await _testFetch(
      label: 'accept-encoding-only',
      url: stream.url,
      headers: <String, String>{
        ...stream.headers,
        'Accept-Encoding': 'identity',
      },
      timeout: const Duration(seconds: 15),
    );

    // ── 7. Fetch with only User-Agent ────────────────────────────────
    print('\n─── Step 6: Re-fetch with User-Agent only ───');
    await _testFetch(
      label: 'ua-only',
      url: stream.url,
      headers: <String, String>{
        ...stream.headers,
        'User-Agent': _browserUserAgent,
      },
      timeout: const Duration(seconds: 15),
    );
  }

  print('\n─── Done ───');
  exit(0);
}

Future<void> _testFetch({
  required String label,
  required Uri url,
  required Map<String, String> headers,
  required Duration timeout,
}) async {
  print('  [$label] GET $url');
  print('  [$label] headers: $headers');

  final client = http.Client();
  try {
    final request = http.Request('GET', url)..headers.addAll(headers);
    final sw = Stopwatch()..start();

    try {
      final response = await client.send(request).timeout(timeout);
      sw.stop();
      print(
        '  [$label] ✓ status=${response.statusCode} '
        'in ${sw.elapsedMilliseconds}ms',
      );

      // Read body to check content
      final bytes = await response.stream
          .toBytes()
          .timeout(const Duration(seconds: 10));
      final body = utf8.decode(bytes, allowMalformed: true);

      final isHls = body.contains('#EXTM3U');
      final lineCount = body.split('\n').length;
      print('  [$label]   body: ${bytes.length} bytes, $lineCount lines');
      print('  [$label]   isHLS: $isHls');
      if (isHls) {
        // Show first 5 lines
        final preview = body.split('\n').take(5).join('\n    ');
        print('  [$label]   preview:\n    $preview');
      } else {
        // Show first 200 chars for debugging
        final preview = body.length > 200 ? body.substring(0, 200) : body;
        print('  [$label]   body preview: $preview');
      }
    } on TimeoutException catch (e) {
      sw.stop();
      print(
        '  [$label] ✗ TIMEOUT after ${sw.elapsedMilliseconds}ms: $e',
      );
    } on http.ClientException catch (e) {
      sw.stop();
      print(
        '  [$label] ✗ ClientException after ${sw.elapsedMilliseconds}ms: $e',
      );
    }
  } finally {
    client.close();
  }
}
