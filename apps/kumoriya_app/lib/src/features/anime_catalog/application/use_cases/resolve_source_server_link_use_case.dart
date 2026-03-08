import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../services/resolver_registry.dart';

final class ResolveSourceServerLinkUseCase {
  const ResolveSourceServerLinkUseCase({required ResolverRegistry registry})
    : _registry = registry;

  final ResolverRegistry _registry;

  Future<Result<List<ResolvedStream>, KumoriyaError>> call(
    SourceServerLink sourceServerLink,
  ) async {
    final url = sourceServerLink.initialUrl;
    if (!url.hasScheme || url.host.trim().isEmpty) {
      return const Failure(
        SimpleError(
          code: 'resolver.malformed_link',
          message: 'Source server link URL is malformed.',
          kind: KumoriyaErrorKind.mapping,
        ),
      );
    }

    final resolver = _registry.findFor(url);
    if (resolver == null) {
      return Failure(
        SimpleError(
          code: 'resolver.no_resolver',
          message: 'No resolver plugin found for host: ${url.host}',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }

    final result = await resolver.resolve(url);
    return result.fold(
      onFailure: Failure.new,
      onSuccess: (streams) {
        if (streams.isEmpty) {
          return const Failure(
            SimpleError(
              code: 'resolver.empty',
              message: 'Resolver returned zero stream candidates.',
              kind: KumoriyaErrorKind.notFound,
            ),
          );
        }
        return Success(streams);
      },
    );
  }
}
