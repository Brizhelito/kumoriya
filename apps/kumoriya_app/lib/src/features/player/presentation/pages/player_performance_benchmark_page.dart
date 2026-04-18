import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kumoriya_resolver_anime_nexus/kumoriya_resolver_anime_nexus.dart';

import '../../../../shared/theme/kumoriya_theme.dart';
import '../../../anime_catalog/application/models/resolved_server_link_result.dart';
import '../../application/services/player_performance_probe.dart';
import 'player_page.dart';

const bool kPlayerPerfBenchmarkMode = bool.fromEnvironment(
  'PLAYER_PERF_BENCHMARK',
  defaultValue: false,
);

const String _benchmarkWatchUrl = String.fromEnvironment(
  'PLAYER_PERF_BENCHMARK_URL',
  defaultValue:
      'https://anime.nexus/watch/019cdcfe-dc32-7328-9747-0e6ef96dbd06/'
      'episode-10-c9b0cd86068190028be1',
);

const int _benchmarkDurationSeconds = int.fromEnvironment(
  'PLAYER_PERF_BENCHMARK_SECONDS',
  defaultValue: 25,
);

class PlayerPerformanceBenchmarkPage extends StatefulWidget {
  const PlayerPerformanceBenchmarkPage({super.key});

  @override
  State<PlayerPerformanceBenchmarkPage> createState() =>
      _PlayerPerformanceBenchmarkPageState();
}

class _PlayerPerformanceBenchmarkPageState
    extends State<PlayerPerformanceBenchmarkPage> {
  final AnimeNexusResolverPlugin _resolver = AnimeNexusResolverPlugin();

  ResolvedServerLinkResult? _resolved;
  String? _error;
  Timer? _finishTimer;

  @override
  void initState() {
    super.initState();
    PlayerPerformanceProbe.instance.startSession(label: 'profile_player_run');
    unawaited(_resolveBenchmarkStream());
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    PlayerPerformanceProbe.instance.finishSession(reason: 'page_disposed');
    super.dispose();
  }

  Future<void> _resolveBenchmarkStream() async {
    PlayerPerformanceProbe.instance.checkpoint('resolve_start');
    final uri = Uri.parse(_benchmarkWatchUrl);
    final result = await _resolver.resolve(uri);
    if (!mounted) {
      return;
    }
    await result.fold(
      onFailure: (error) async {
        PlayerPerformanceProbe.instance.checkpoint('resolve_failure');
        setState(() {
          _error = '${error.code}: ${error.message}';
        });
        _finishWithExit(reason: 'resolve_failure', code: 1);
      },
      onSuccess: (value) async {
        PlayerPerformanceProbe.instance.checkpoint(
          'resolve_success_streams_${value.streams.length}',
        );
        setState(() {
          _resolved = ResolvedServerLinkResult(
            resolverId: 'anime_nexus',
            resolverName: 'Anime Nexus',
            streams: value.streams,
            externalSubtitles: value.externalSubtitles,
          );
        });
        _finishTimer = Timer(
          const Duration(seconds: _benchmarkDurationSeconds),
          () => _finishWithExit(reason: 'benchmark_window_elapsed'),
        );
      },
    );
  }

  void _finishWithExit({required String reason, int code = 0}) {
    if (!mounted) {
      return;
    }
    PlayerPerformanceProbe.instance.checkpoint(reason);
    PlayerPerformanceProbe.instance.finishSession(reason: reason);
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      exit(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    if (resolved != null) {
      return PlayerPage(
        anilistId: 0,
        animeTitle: 'Anime Nexus Benchmark',
        episodeNumber: '10',
        sourcePluginId: 'anime_nexus',
        serverName: 'benchmark',
        persistSelection: false,
        resolved: resolved,
      );
    }

    return Scaffold(
      backgroundColor: KumoriyaColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(color: KumoriyaColors.primary),
              const SizedBox(height: 16),
              Text(
                _error == null
                    ? 'Resolving benchmark stream...'
                    : 'Benchmark failed: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: KumoriyaColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
