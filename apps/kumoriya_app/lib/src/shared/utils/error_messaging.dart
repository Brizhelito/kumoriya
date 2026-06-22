import 'package:flutter/material.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../../app/l10n.dart';

String mapErrorMessage(BuildContext context, KumoriyaError error) {
  if (error.code.startsWith('player.')) {
    switch (error.code) {
      case 'player.no_playable_stream':
        return context.l10n.playerNoPlayableStream;
      case 'player.unsupported_stream':
        return context.l10n.playerUnsupportedStream;
      case 'player.open_timeout':
        return context.l10n.playerOpenTimeout;
      case 'player.buffering_timeout':
        return context.l10n.playerBufferingTimeout;
      case 'player.network_failure':
        return context.l10n.playerNetworkFailure;
      case 'player.candidate_failed':
        return context.l10n.playerCandidateFailedTryingFallback;
      case 'player.all_candidates_failed':
        return context.l10n.playerAllCandidatesFailed;
      case 'player.open_failed':
        return context.l10n.playerOpenFailed;
      case 'player.playback_error':
        return context.l10n.playerPlaybackErrorGeneric;
    }
  }

  if (error.code.startsWith('resolver.')) {
    switch (error.code) {
      case 'resolver.no_resolver':
      case 'resolver.jkplayer.unsupported_host':
        return context.l10n.resolverNoResolverFound;
      case 'resolver.ambiguous':
        return context.l10n.resolverAmbiguousSelection;
      case 'resolver.malformed_link':
      case 'resolver.jkplayer.malformed_link':
        return context.l10n.resolverMalformedLink;
      case 'resolver.jkplayer.parse':
        return context.l10n.resolverParseFailure;
      case 'resolver.jkplayer.inconsistent':
        return context.l10n.resolverInconsistentPayload;
      case 'resolver.empty':
        return context.l10n.resolverNoStreams;
    }

    switch (error.kind) {
      case KumoriyaErrorKind.transport:
        return context.l10n.resolverTransportFailure;
      case KumoriyaErrorKind.mapping:
        return context.l10n.resolverParseFailure;
      case KumoriyaErrorKind.notFound:
        return context.l10n.resolverNoResolverFound;
      case KumoriyaErrorKind.unexpected:
        return context.l10n.resolverUnexpectedFailure;
      case KumoriyaErrorKind.cancelled:
        return context.l10n.resolverTransportFailure;
    }
  }

  if (error.code.startsWith('jkanime.')) {
    switch (error.code) {
      case 'jkanime.parse':
        return context.l10n.errorJkanimeParse;
      case 'jkanime.inconsistent':
        return context.l10n.errorJkanimeInconsistent;
      case 'jkanime.empty':
        return context.l10n.errorJkanimeEmpty;
    }

    switch (error.kind) {
      case KumoriyaErrorKind.transport:
        return context.l10n.errorTransportSource;
      case KumoriyaErrorKind.mapping:
        return context.l10n.errorMappingSource;
      case KumoriyaErrorKind.notFound:
        return context.l10n.errorNotFoundSource;
      case KumoriyaErrorKind.unexpected:
        return context.l10n.errorUnexpectedSource;
      case KumoriyaErrorKind.cancelled:
        return context.l10n.errorTransportSource;
    }
  }

  if (error.code.startsWith('anilist.')) {
    if (error.code == 'anilist.rate_limit') {
      return context.l10n.errorRateLimitedAnilist;
    }
    if (error.code == 'anilist.service_unavailable') {
      return context.l10n.errorServiceUnavailableAnilist;
    }

    switch (error.kind) {
      case KumoriyaErrorKind.transport:
        return context.l10n.errorTransportAnilist;
      case KumoriyaErrorKind.mapping:
        return context.l10n.errorMappingAnilist;
      case KumoriyaErrorKind.notFound:
        return context.l10n.errorNotFoundAnilist;
      case KumoriyaErrorKind.unexpected:
        return context.l10n.errorUnexpectedAnilist;
      case KumoriyaErrorKind.cancelled:
        return context.l10n.errorTransportAnilist;
    }
  }

  if (error.code.startsWith('anime_nexus.') ||
      error.code.startsWith('animeflv.') ||
      error.code.startsWith('animeav1.') ||
      error.code.startsWith('source.') ||
      error.code.startsWith('storage.')) {
    switch (error.kind) {
      case KumoriyaErrorKind.transport:
        return context.l10n.errorTransportSource;
      case KumoriyaErrorKind.mapping:
        return context.l10n.errorMappingSource;
      case KumoriyaErrorKind.notFound:
        return context.l10n.errorNotFoundSource;
      case KumoriyaErrorKind.unexpected:
        return context.l10n.errorUnexpectedSource;
      case KumoriyaErrorKind.cancelled:
        return context.l10n.errorTransportSource;
    }
  }

  switch (error.kind) {
    case KumoriyaErrorKind.transport:
      return context.l10n.errorTransportSource;
    case KumoriyaErrorKind.mapping:
      return context.l10n.errorMappingSource;
    case KumoriyaErrorKind.notFound:
      return context.l10n.errorNotFoundSource;
    case KumoriyaErrorKind.unexpected:
      return context.l10n.errorUnexpectedSource;
    case KumoriyaErrorKind.cancelled:
      return context.l10n.errorTransportSource;
  }
}
