import 'package:flutter/material.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../../app/l10n.dart';
import '../icons/kumoriya_icons.dart';
import '../theme/kumoriya_theme.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? context.l10n.loadingGeneric;
    return Semantics(
      liveRegion: true,
      label: effectiveLabel,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              Text(
                effectiveLabel,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, size: 48, color: KumoriyaColors.navInactive),
                const SizedBox(height: 16),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                KumoriyaIcons.error,
                size: 48,
                color: KumoriyaColors.statusDanger,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(KumoriyaIcons.refresh),
                  label: Text(context.l10n.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class UnavailableStateView extends StatelessWidget {
  const UnavailableStateView({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      title: title,
      icon: Icons.cloud_off_rounded,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class StateTransitionSwitcher extends StatelessWidget {
  const StateTransitionSwitcher({
    super.key,
    required this.stateKey,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  final Object stateKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        return FadeTransition(opacity: animation, child: widget);
      },
      child: KeyedSubtree(key: ValueKey<Object>(stateKey), child: child),
    );
  }
}

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
