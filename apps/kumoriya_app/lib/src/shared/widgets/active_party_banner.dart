import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../theme/kumoriya_theme.dart';
import '../../features/watch_party/application/providers/party_providers.dart';
import '../../features/watch_party/presentation/pages/party_anime_page.dart';

/// Banner shown on the home screen when there is an active watch party
/// session, allowing the user to re-enter the flow with one tap.
class ActivePartyBanner extends ConsumerWidget {
  const ActivePartyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(partySessionProvider);
    if (!session.isActive || session.room == null) {
      return const SizedBox.shrink();
    }
    final room = session.room!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A3A), Color(0xFF0F1A26)],
        ),
        border: Border(bottom: BorderSide(color: KumoriyaColors.borderSubtle)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: KumoriyaColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: KumoriyaColors.primaryLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.partyBannerTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.l10n.partyBannerSubtitle(
                      room.animeTitle,
                      room.episodeNumber.toInt(),
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: KumoriyaColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _navigateToParty(context, ref),
              child: Text(
                context.l10n.partyBannerRejoin,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToParty(BuildContext context, WidgetRef ref) {
    final room = ref.read(partySessionProvider).room;
    if (room == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PartyAnimePage(anilistId: room.anilistId),
      ),
    );
  }
}
