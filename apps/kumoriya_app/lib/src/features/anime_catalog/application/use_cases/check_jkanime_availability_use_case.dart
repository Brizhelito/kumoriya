import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../matching/anilist_source_matcher.dart';
import '../models/source_availability.dart';
import 'check_source_availability_use_case.dart';

final class CheckJkanimeAvailabilityUseCase {
  CheckJkanimeAvailabilityUseCase({
    required SourcePlugin sourcePlugin,
    required AnilistSourceMatcher matcher,
  }) : _delegate = CheckSourceAvailabilityUseCase(
         sourcePlugin: sourcePlugin,
         matcher: matcher,
       );

  final CheckSourceAvailabilityUseCase _delegate;

  Future<Result<SourceAvailability, KumoriyaError>> call(
    AnimeDetail anilistDetail,
  ) async {
    return Success(await _delegate.call(anilistDetail));
  }
}
