import 'dart:async';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_plugins/kumoriya_plugins.dart';
import 'package:kumoriya_resolver_common/kumoriya_resolver_common.dart';

import '../models/resolved_server_link_result.dart';
import '../services/resolver_registry.dart';

final class ResolveSourceServerLinkUseCase {
  ResolveSourceServerLinkUseCase({
    required ResolverRegistry registry,
    Duration resolveTimeout = const Duration(seconds: 20),
    http.Client? streamVerifyClient,
    Duration streamVerifyTimeout = const Duration(seconds: 3),
  }) : _registry = registry,
       _resolveTimeout = resolveTimeout,
       _verifyClient = streamVerifyClient,
       _verifyTimeout = streamVerifyTimeout;

  final ResolverRegistry _registry;
  final Duration _resolveTimeout;
  final http.Client? _verifyClient;
  final Duration _verifyTimeout;

  Future<Result<ResolvedServerLinkResult, KumoriyaError>> call(
    SourceServerLink sourceServerLink, {
    String? preferredResolverId,
  }) async {
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

    ResolverPlugin? preferredResolver;
    if (preferredResolverId != null && preferredResolverId.isNotEmpty) {
      final candidate = _registry.resolverById(preferredResolverId);
      if (candidate != null && candidate.supports(url)) {
        preferredResolver = candidate;
      } else {
        _log(
          'preferred resolver ignored server=${sourceServerLink.serverName} '
          'preferred=$preferredResolverId url=$url',
        );
      }
    }

    final selection = preferredResolver == null
        ? _registry.selectFor(url)
        : null;
    if (preferredResolver == null && selection is ResolverNotFound) {
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
    if (preferredResolver == null && selection is ResolverAmbiguous) {
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
    final resolver =
        preferredResolver ?? ((selection as ResolverSelected).resolver);
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

    final resolveOutcome = result.fold(
      onFailure: (error) {
        _log(
          'resolve failure server=${sourceServerLink.serverName} resolver=${resolver.manifest.id} code=${error.code} message=${error.message}',
        );
        return Failure<ResolvedServerLinkResult, KumoriyaError>(error);
      },
      onSuccess: (resolveResult) {
        if (resolveResult.streams.isEmpty) {
          _log(
            'resolve empty server=${sourceServerLink.serverName} resolver=${resolver.manifest.id}',
          );
          return const Failure<ResolvedServerLinkResult, KumoriyaError>(
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
        return Success<ResolvedServerLinkResult, KumoriyaError>(
          ResolvedServerLinkResult(
            resolverId: resolver.manifest.id,
            resolverName: resolver.manifest.displayName,
            streams: resolveResult.streams,
            externalSubtitles: mergedSubtitles,
          ),
        );
      },
    );

    // Skip verification if no client was provided or resolution already failed.
    if (_verifyClient == null || resolveOutcome is Failure) {
      return resolveOutcome;
    }

    final resolved =
        (resolveOutcome as Success<ResolvedServerLinkResult, KumoriyaError>)
            .value;
    final verifiedStreams = await _verifyAndFilter(
      resolved.streams,
      serverName: sourceServerLink.serverName,
      resolverId: resolver.manifest.id,
    );

    if (verifiedStreams.isEmpty) {
      _log(
        'verify all rejected server=${sourceServerLink.serverName} resolver=${resolver.manifest.id}',
      );
      return const Failure(
        SimpleError(
          code: 'resolver.all_streams_rejected',
          message:
              'All resolved streams failed pre-verification (non-video response).',
          kind: KumoriyaErrorKind.notFound,
        ),
      );
    }

    if (verifiedStreams.length < resolved.streams.length) {
      _log(
        'verify filtered ${resolved.streams.length - verifiedStreams.length} streams '
        'server=${sourceServerLink.serverName} resolver=${resolver.manifest.id}',
      );
    }

    return Success(
      ResolvedServerLinkResult(
        resolverId: resolved.resolverId,
        resolverName: resolved.resolverName,
        streams: verifiedStreams,
        externalSubtitles: resolved.externalSubtitles,
      ),
    );
  }

  /// Verify all [streams] concurrently and return only those that are not
  /// definitively rejected. Uncertain outcomes are kept (conservative).
  Future<List<ResolvedStream>> _verifyAndFilter(
    List<ResolvedStream> streams, {
    required String serverName,
    required String resolverId,
  }) async {
    final outcomes = await Future.wait(
      streams.map(
        (s) =>
            verifyStreamUrl(
              s.url,
              s.headers,
              timeout: _verifyTimeout,
              client: _verifyClient,
            ).then((outcome) {
              if (outcome == StreamVerifyOutcome.rejected) {
                _log(
                  'verify rejected stream server=$serverName resolver=$resolverId url=${s.url}',
                );
              }
              return (stream: s, outcome: outcome);
            }),
      ),
    );
    return [
      for (final r in outcomes)
        if (r.outcome != StreamVerifyOutcome.rejected) r.stream,
    ];
  }

  void _log(String message) {
    developer.log(message, name: 'kumoriya.resolve_source_server_link');
  }
}
