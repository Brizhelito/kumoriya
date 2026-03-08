import 'package:kumoriya_storage/kumoriya_storage.dart';

void main() {
  final progress = EpisodeProgress(
    anilistId: 1,
    episodeNumber: 1,
    position: const Duration(minutes: 1),
    updatedAt: DateTime.now(),
  );
  print(progress.episodeNumber);
}
