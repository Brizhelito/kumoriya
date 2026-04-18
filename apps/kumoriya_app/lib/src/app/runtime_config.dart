import 'package:flutter/foundation.dart';
import 'package:kumoriya_anilist/kumoriya_anilist.dart';

final class KumoriyaRuntimeConfig {
  const KumoriyaRuntimeConfig._();

  /// Base URL for the Kumoriya Go backend (auth, sync, AniList-home cache,
  /// watch-party, etc). Override at build time via
  /// `--dart-define=KUMORIYA_API_BASE_URL=...`.
  static const String apiBaseUrl = String.fromEnvironment(
    'KUMORIYA_API_BASE_URL',
    defaultValue: 'https://api.kumoriya.online',
  );

  static AnilistClientConfig get anilistClient => AnilistClientConfig(
    collectDebugMetrics: kDebugMode,
    debugLogLevel: AnilistClientLogLevel.off,
  );
}
