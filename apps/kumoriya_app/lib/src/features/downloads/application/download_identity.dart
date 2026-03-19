import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:kumoriya_storage/kumoriya_storage.dart';

String formatEpisodeIdentityNumber(double episodeNumber) {
  if (episodeNumber == episodeNumber.roundToDouble()) {
    return episodeNumber.toStringAsFixed(0);
  }
  return episodeNumber
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String buildDownloadIdentityKey({
  required int anilistId,
  required double episodeNumber,
}) {
  return '$anilistId:${formatEpisodeIdentityNumber(episodeNumber)}';
}

String buildDownloadTaskId({
  required int anilistId,
  required double episodeNumber,
}) {
  final digest = sha256.convert(
    utf8.encode(
      buildDownloadIdentityKey(
        anilistId: anilistId,
        episodeNumber: episodeNumber,
      ),
    ),
  );
  return 'dl_$digest';
}

bool isSameDownloadEpisode(
  DownloadTask task, {
  required int anilistId,
  required double episodeNumber,
}) {
  return task.anilistId == anilistId &&
      formatEpisodeIdentityNumber(task.episodeNumber) ==
          formatEpisodeIdentityNumber(episodeNumber);
}
