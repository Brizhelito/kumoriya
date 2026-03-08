import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:test/test.dart';

void main() {
  test('package exports AniList integration types', () {
    expect(AnilistMetadataGateway, isNotNull);
    expect(AnilistAnimeCatalogRepository, isNotNull);
  });
}
