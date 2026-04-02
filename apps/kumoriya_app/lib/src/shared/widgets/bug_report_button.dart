import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// A button that opens a feedback dialog and sends the report to Sentry.
///
/// Drop it anywhere — settings screen, drawer, long-press menu, etc.
///
/// ```dart
/// const BugReportButton()
/// ```
class BugReportButton extends StatelessWidget {
  const BugReportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.bug_report_outlined),
      label: const Text('Reportar error'),
      onPressed: () => _showDialog(context),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _BugReportDialog(),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _submit(result.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado. ¡Gracias!')),
        );
      }
    }
  }

  Future<void> _submit(String message) async {
    // Capture as a Sentry message so it appears in the Issues dashboard.
    final eventId = await Sentry.captureMessage(
      '[user-report] $message',
      level: SentryLevel.info,
      withScope: (scope) {
        scope.setTag('type', 'user_report');
      },
    );

    // Attach user feedback linked to the event for the Feedback tab.
    await Sentry.captureFeedback(
      SentryFeedback(message: message, associatedEventId: eventId),
    );
  }
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar error'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué pasó? Describe el problema brevemente.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText:
                  'Ej: La app se cerró al presionar reproducir en el episodio 3',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting
              ? null
              : () {
                  if (_controller.text.trim().isEmpty) return;
                  setState(() => _submitting = true);
                  Navigator.of(context).pop(_controller.text);
                },
          child: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}
