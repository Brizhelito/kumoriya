// ignore_for_file: avoid_print
/// Full resolver flow with NexusPageScraper (to get initial cookies)
library;

import 'package:test/test.dart';

import 'package:kumoriya_resolver_anime_nexus/src/anime_nexus_resolver_plugin.dart';

void main() {
  test(
    'Full WS flow via resolver plugin',
    () async {
      const watchUrl =
          'https://anime.nexus/watch/019b9e8f-edf6-71a7-87c5-c45f64297245/execution-537a058e13efbfab1729';

      print('[1] Initialize resolver plugin...');
      final resolver = AnimeNexusResolverPlugin(
        onDebugLog: (msg) => print('[resolver] $msg'),
      );

      print('[2] Call resolve()...');
      try {
        final result = await resolver.resolve(Uri.parse(watchUrl));
        print('[2] resolve returned: ${result.runtimeType}');

        // Check if it's Success or Failure
        result.fold(
          onFailure: (error) {
            print('[FAILED] Error: $error');
          },
          onSuccess: (result) {
            final streams = result.streams;
            print('[SUCCESS] Got ${streams.length} streams');
            for (final stream in streams) {
              print('  ✓ $stream');
            }
          },
        );
      } catch (e, st) {
        print('[EXCEPTION] $e');
        print('[STACK] $st');
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
