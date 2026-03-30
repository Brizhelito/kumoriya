import 'package:flutter/foundation.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';

final class KumoriyaRuntimeConfig {
  const KumoriyaRuntimeConfig._();

  static AnilistClientConfig get anilistClient => AnilistClientConfig(
    collectDebugMetrics: kDebugMode,
    debugLogLevel: kDebugMode
        ? AnilistClientLogLevel.summary
        : AnilistClientLogLevel.off,
  );
}
