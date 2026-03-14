import 'package:kumoriya_resolver_anime_nexus/src/models/nexus_browser_session.dart';
import 'package:test/test.dart';

void main() {
  group('NexusBrowserSession', () {
    test('preserves generated sid when adding response cookies', () {
      final session = NexusBrowserSession.generate();
      final sidBefore = session.cookieHeader!;

      final merged = session.withCookieHeader(
        'anime_nexus_session=abc123; application_viewable=1',
      );

      expect(merged.cookieHeader, contains(sidBefore));
      expect(merged.cookieHeader, contains('anime_nexus_session=abc123'));
      expect(merged.cookieHeader, contains('application_viewable=1'));
    });
  });
}
