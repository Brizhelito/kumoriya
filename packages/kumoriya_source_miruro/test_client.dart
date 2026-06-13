import 'package:kumoriya_source_miruro/src/miruro_client.dart';

void main() async {
  final client = MiruroClient();
  try {
    print('Testing pipeRequest for episodes...');
    final response = await client.pipeRequest(
      'episodes',
      query: {'anilistId': '21'},
    );
    print('Success! Response keys: ${response.keys}');
    if (response.containsKey('providers')) {
      final providers = response['providers'] as Map<String, dynamic>;
      print('Providers: ${providers.keys}');
      if (providers.containsKey('kiwi')) {
        final kiwi = providers['kiwi'] as Map<String, dynamic>;
        final episodes = kiwi['episodes'] as Map<String, dynamic>;
        final sub = episodes['sub'] as List<dynamic>;
        print('Kiwi sub episodes: ${sub.length}');
        if (sub.isNotEmpty) {
          print('First episode: ${sub.first}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
