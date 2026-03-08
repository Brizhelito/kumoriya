import 'package:flutter/material.dart';
import 'package:kumoriya_core/kumoriya_core.dart';

import '../../app/l10n.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label ?? context.l10n.loadingGeneric),
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (onRetry != null)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retry),
              ),
          ],
        ),
      ),
    );
  }
}

String mapErrorMessage(BuildContext context, KumoriyaError error) {
  if (error.code.startsWith('jkanime.')) {
    switch (error.kind) {
      case KumoriyaErrorKind.transport:
        return context.l10n.errorTransportSource;
      case KumoriyaErrorKind.mapping:
        return context.l10n.errorMappingSource;
      case KumoriyaErrorKind.notFound:
        return context.l10n.errorNotFoundSource;
      case KumoriyaErrorKind.unexpected:
        return context.l10n.errorUnexpectedSource;
    }
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
  }
}
