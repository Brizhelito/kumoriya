import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/voice_state.dart';
import '../../infrastructure/webrtc_peer_manager.dart';
import 'party_providers.dart';

final voiceSessionProvider =
    NotifierProvider<VoiceSessionNotifier, PartyVoiceState>(
      VoiceSessionNotifier.new,
    );

class VoiceSessionNotifier extends Notifier<PartyVoiceState> {
  VoicePeerManager? _manager;
  StreamSubscription? _eventsSub;

  // Tracks whether the event listener + manager are wired up (no mic yet).
  bool _isWired = false;

  @override
  PartyVoiceState build() {
    ref.onDispose(() {
      _eventsSub?.cancel();
      _manager?.dispose();
    });
    return const PartyVoiceState();
  }

  // ── Public surface ──────────────────────────────────────────────────────────

  /// Called by PTT button on first interaction.
  /// Wires up signaling, requests mic permission, and acquires the stream.
  /// Returns true if voice is ready to use.
  Future<bool> activate(String localUserId) async {
    _wireEvents(localUserId);

    // Request mic permission — only now, triggered by user gesture.
    final status = await Permission.microphone.request();
    final granted = status.isGranted;

    state = state.copyWith(hasPermission: granted);
    if (!granted) return false;

    final ok = await _manager!.acquireMicrophone();
    state = state.copyWith(isInitialized: ok);
    if (!ok) return false;

    // Connect to already-present room members with staggered delays
    // to avoid overwhelming the WebRTC signaling thread.
    final room = ref.read(partySessionProvider).room;
    if (room != null) {
      for (final member in room.members) {
        if (member.userId != localUserId) {
          await _manager!.connectToPeer(member.userId, createOffer: true);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    return true;
  }

  /// Called when PTT button is long-pressed (already activated).
  void setMicEnabled(bool enabled) {
    _manager?.setMicEnabled(enabled);
    state = state.copyWith(isMicEnabled: enabled);

    final sessionNotifier = ref.read(partySessionProvider.notifier);
    sessionNotifier.realtimeClient?.sendVoiceState(speaking: enabled);
  }

  /// Peer disconnected.
  Future<void> disconnectPeer(String peerId) async {
    await _manager?.handlePeerLeft(peerId);
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Wire up the VoicePeerManager and WebSocket event subscription.
  /// Safe to call multiple times — idempotent.
  void _wireEvents(String localUserId) {
    if (_isWired) return;
    _isWired = true;

    final sessionNotifier = ref.read(partySessionProvider.notifier);
    final realtimeClient = sessionNotifier.realtimeClient;
    if (realtimeClient == null) return;

    _manager = VoicePeerManager(
      localUserId: localUserId,
      sendSignal: (targetUserId, type, signal) {
        realtimeClient.sendWebRtcSignal(
          targetUserId: targetUserId,
          type: type,
          signal: signal,
        );
      },
      onPeerStateChange: (peerId, connected) {
        final peers = Set<String>.from(state.connectedVoicePeers);
        if (connected) {
          peers.add(peerId);
        } else {
          peers.remove(peerId);
        }
        state = state.copyWith(connectedVoicePeers: peers);
      },
    );

    _eventsSub = realtimeClient.events.listen((event) {
      switch (event.type) {
        case 'webrtc_signal':
          final payload = event.payload;
          final senderId = payload['senderId'] as String?;
          final type = payload['type'] as String?;
          final signal = payload['signal'];
          if (senderId != null && type != null && signal != null) {
            _manager?.handleSignal(senderId, type, signal);
          }

        case 'voice_state_changed':
          final payload = event.payload;
          final userId = payload['userId'] as String?;
          final speaking = payload['speaking'] as bool? ?? false;
          if (userId != null) {
            final speakingPeers = Set<String>.from(state.speakingPeers);
            if (speaking) {
              speakingPeers.add(userId);
            } else {
              speakingPeers.remove(userId);
            }
            state = state.copyWith(speakingPeers: speakingPeers);
          }

        case 'member_joined':
          // Only connect if voice is already active (mic acquired).
          if (!state.isInitialized) return;
          final payload = event.payload;
          final joinedUserId = payload['userId'] as String?;
          if (joinedUserId != null && joinedUserId != localUserId) {
            _manager?.connectToPeer(joinedUserId, createOffer: true);
          }

        case 'member_left':
          final payload = event.payload;
          final leftUserId = payload['userId'] as String?;
          if (leftUserId != null) {
            disconnectPeer(leftUserId);
          }
      }
    });
  }
}
