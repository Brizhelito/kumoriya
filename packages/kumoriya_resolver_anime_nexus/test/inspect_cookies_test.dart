// ignore_for_file: avoid_print
/// Check what cookies/headers the stream data endpoint returns
library;

import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test(
    'inspect Set-Cookie headers from stream data fetch',
    () async {
      const episodeId = '019b9e8f-edf6-71a7-87c5-c45f64297245';

      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

      final url =
          'https://api.anime.nexus/api/anime/details/episode/stream'
          '?id=$episodeId'
          '&fillers=true'
          '&recaps=true';

      try {
        print('[1] Fetch stream data endpoint...');
        final response = await dio.get<dynamic>(url);

        print('[2] Response status: ${response.statusCode}');
        print('[3] Check response headers...');
        response.headers.forEach((key, val) {
          if (key.toLowerCase().contains('cookie') ||
              key.toLowerCase().contains('auth') ||
              key.toLowerCase().contains('set-')) {
            print('    $key: $val');
          }
        });

        print('[4] All headers:');
        response.headers.forEach((key, val) {
          print('    $key: ${val.join('; ')}');
        });
      } catch (e) {
        print('[!] Error: $e');
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
