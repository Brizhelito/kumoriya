import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/resolved_server_link_result.dart';
import '../services/resolver_registry.dart';

final class ResolveSourceServerLinkUseCase {
  const ResolveSourceServerLinkUseCase({required ResolverRegistry registry})
    : _registry = registry;

  final ResolverRegistry _registry;

  Future<Result<ResolvedServerLinkResult, KumoriyaError>> call(
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

    final selection = _registry.selectFor(url);
    if (selection is ResolverNotFound) {
      return Failure(
        SimpleError(
          code: 'resolver.no_resolver',
          message:
              'No resolver plugin found for host/path: ${url.host}${url.path}',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }
    if (selection is ResolverAmbiguous) {
      final resolverIds = selection.resolvers
          .map((r) => r.manifest.id)
          .join(', ');
      return Failure(
        SimpleError(
          code: 'resolver.ambiguous',
          message:
              'Multiple resolvers match this URL with same priority: $resolverIds',
          kind: KumoriyaErrorKind.unexpected,
        ),
      );
    }
    final resolver = (selection as ResolverSelected).resolver;

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
        return Success(
          ResolvedServerLinkResult(
            resolverId: resolver.manifest.id,
            resolverName: resolver.manifest.displayName,
            streams: streams,
          ),
        );
      },
    );
  }
}
