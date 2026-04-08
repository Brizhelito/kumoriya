import 'package:http/http.dart' as http;
import 'package:kumoriya_resolver_mediafire/kumoriya_resolver_mediafire.dart';

void main() async {
  // 1. Test: resolve() with a proxy URL (simulated)
  // Real proxy: https://c1.jkplayers.com/d/{token}/
  // It should 302 → mediafire.com/file/... or download*.mediafire.com/...

  // Let's test with a real proxy URL from JKAnime if we have one.
  // Actually, let's just check the redirect behavior of a known proxy-like URL.
  
  final r = MediafireResolverPlugin();
  
  // Simulate what happens: resolve() calls with the raw proxy URL.
  // _supportedHosts.contains('c1.jkplayers.com') == false → goes to _resolveProxy()
  // _resolveProxy does followRedirects=false and follows manually.

  // This URL would fail in real life without a valid token, but let's see the error.
  print('-- Testing resolve() with non-mediafire URL --');
  final result = await r.resolve(Uri.parse('https://c1.jkplayers.com/d/invalidtoken/'));
  result.fold(
    onSuccess: (v) => print('SUCCESS: ${v.streams.length} streams'),
    onFailure: (e) => print('FAILURE: [${e.code}] ${e.message}'),
  );

  // Test 2: resolve with actual mediafire URL
  print('-- Testing resolve() with actual MediaFire URL --');
  final result2 = await r.resolve(Uri.parse('https://www.mediafire.com/file/test123/video.mp4'));
  result2.fold(
    onSuccess: (v) => print('SUCCESS: ${v.streams.length} streams'),
    onFailure: (e) => print('FAILURE: [${e.code}] ${e.message}'),
  );
}
