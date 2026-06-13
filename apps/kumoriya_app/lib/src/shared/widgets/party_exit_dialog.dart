import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';

/// Enum result for the party exit dialog.
enum PartyExitAction { leave, cancel }

/// Confirmation dialog shown when leaving a watch party from the lobby.
///
/// Two options: Stay (cancel) / Leave Party (leave + pop).
Future<PartyExitAction?> showPartyExitDialog(BuildContext context) {
  return showDialog<PartyExitAction>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: KumoriyaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      ),
      title: Row(
        children: [
          Icon(Icons.exit_to_app, color: KumoriyaColors.statusDanger, size: 22),
          const SizedBox(width: 10),
          Text(
            context.l10n.partyExitTitle,
            style: TextStyle(color: KumoriyaColors.textPrimary),
          ),
        ],
      ),
      content: Text(
        context.l10n.partyExitBody,
        style: TextStyle(color: KumoriyaColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, PartyExitAction.cancel),
          child: Text(
            context.l10n.partyExitStay,
            style: TextStyle(color: KumoriyaColors.textSecondary),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: KumoriyaColors.statusDanger,
          ),
          onPressed: () => Navigator.pop(ctx, PartyExitAction.leave),
          child: Text(context.l10n.partyExitLeave),
        ),
      ],
    ),
  );
}

/// Enum result for the player exit dialog (party mode).
enum PartyPlayerExitAction { cancel, backToParty, leaveParty }

/// Three-option dialog shown when exiting the player during a watch party.
///
/// - [PartyPlayerExitAction.backToParty]: pop to PartyAnimePage
/// - [PartyPlayerExitAction.leaveParty]: leaveRoom + pop to root
/// - [PartyPlayerExitAction.cancel]: dismiss, stay in player
Future<PartyPlayerExitAction?> showPartyPlayerExitDialog(BuildContext context) {
  return showDialog<PartyPlayerExitAction>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: KumoriyaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KumoriyaRadius.xl),
      ),
      title: Row(
        children: [
          Icon(Icons.groups, color: KumoriyaColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            context.l10n.partyPlayerExitTitle,
            style: TextStyle(color: KumoriyaColors.textPrimary),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionTile(
            icon: Icons.arrow_back_rounded,
            iconColor: KumoriyaColors.primary,
            title: context.l10n.partyPlayerExitBackToParty,
            subtitle: context.l10n.partyPlayerExitBackToPartyDesc,
            onTap: () => Navigator.pop(ctx, PartyPlayerExitAction.backToParty),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.exit_to_app,
            iconColor: KumoriyaColors.statusDanger,
            title: context.l10n.partyPlayerExitLeave,
            subtitle: context.l10n.partyPlayerExitLeaveDesc,
            onTap: () => Navigator.pop(ctx, PartyPlayerExitAction.leaveParty),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, PartyPlayerExitAction.cancel),
          child: Text(
            context.l10n.partyPlayerExitCancel,
            style: TextStyle(color: KumoriyaColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KumoriyaColors.background,
          borderRadius: BorderRadius.circular(KumoriyaRadius.lg),
          border: Border.all(color: KumoriyaColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: KumoriyaColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: KumoriyaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
