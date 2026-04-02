import 'dart:async';
import 'dart:developer' as developer;

import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';

import '../models/resolved_server_link_result.dart';
import '../services/resolver_registry.dart';

final class ResolveSourceServerLinkUseCase {
  const ResolveSourceServerLinkUseCase({
    required ResolverRegistry registry,
    Duration resolveTimeout = const Duration(seconds: 20),
  }) : _registry = registry,
       _resolveTimeout = resolveTimeout;

  final ResolverRegistry _registry;
  final Duration _resolveTimeout;

  Future<Result<ResolvedServerLinkResult, KumoriyaError>> call(
    SourceServerLink sourceServerLink,
  ) async {
    final url = sourceServerLink.initialUrl;
    if (!url.hasScheme || url.host.trim().isEmpty) {
      _log('reject malformed server=${sourceServerLink.serverName} url=$url');
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
      _log('reject no-resolver server=${sourceServerLink.serverName} url=$url');
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
      _log(
        'reject ambiguous server=${sourceServerLink.serverName} url=$url resolvers=$resolverIds',
      );
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
    _log(
      'resolve start server=${sourceServerLink.serverName} resolver=${resolver.manifest.id} url=$url',
    );

    Result<ResolveResult, KumoriyaError> result;
    try {
      result = await resolver.resolve(url).timeout(_resolveTimeout);
    } on TimeoutException {
      _log(
        'resolve timeout server=${sourceServerLink.serverName} resolver=${resolver.manifest.id} url=$url',
      );
      return Failure(
        SimpleError(
          code: 'resolver.timeout',
          message:
              'Resolver timed out for ${sourceServerLink.serverName} after ${_resolveTimeout.inSeconds}s.',
          kind: KumoriyaErrorKind.transport,
        ),
      );
    }

    return result.fold(
      onFailure: (error) {
        _log(
          'resolve failure server=${sourceServerLink.serverName} resolver=${resolver.manifest.id} code=${error.code} message=${error.message}',
        );
        return Failure(error);
      },
      onSuccess: (resolveResult) {
        if (resolveResult.streams.isEmpty) {
          _log(
            'resolve empty server=${sourceServerLink.serverName} resolver=${resolver.manifest.id}',
          );
          return const Failure(
            SimpleError(
              code: 'resolver.empty',
              message: 'Resolver returned zero stream candidates.',
              kind: KumoriyaErrorKind.notFound,
            ),
          );
        }
        // Merge subtitles: resolver-provided tracks take priority,
        // source-provided tracks are appended as fallback.
        final mergedSubtitles = <ExternalSubtitleTrack>[
          ...resolveResult.externalSubtitles,
          ...sourceServerLink.externalSubtitles,
        ];
        _log(
          'resolve success server=${sourceServerLink.serverName} resolver=${resolver.manifest.id} streams=${resolveResult.streams.length} subtitles=${mergedSubtitles.length}',
        );
        return Success(
          ResolvedServerLinkResult(
            resolverId: resolver.manifest.id,
            resolverName: resolver.manifest.displayName,
            streams: resolveResult.streams,
            externalSubtitles: mergedSubtitles,
          ),
        );
      },
    );
  }

  void _log(String message) {
    developer.log(message, name: 'kumoriya.resolve_source_server_link');
  }
}
