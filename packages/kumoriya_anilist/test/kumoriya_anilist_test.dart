import 'package:kumoriya_anilist/kumoriya_anilist.dart';
import 'package:test/test.dart';

void main() {
  test('anilist package exports contract', () {
    expect(AnilistMetadataGateway, isNotNull);
  });
}
