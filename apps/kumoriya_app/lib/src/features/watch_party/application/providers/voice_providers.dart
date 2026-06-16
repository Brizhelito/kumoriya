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

  @override
  PartyVoiceState build() {
    ref.onDispose(() {
      _eventsSub?.cancel();
      _manager?.dispose();
    });
    return const PartyVoiceState();
  }

  /// Initialize voice chat if permission is granted and WebSocket is active.
  Future<void> initialize(String localUserId) async {
    final sessionNotifier = ref.read(partySessionProvider.notifier);
    final realtimeClient = sessionNotifier.realtimeClient;
    if (realtimeClient == null) return;

    // Request permission using permission_handler
    final status = await Permission.microphone.request();
    final hasPermission = status.isGranted;

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

    final isInitialized = await _manager!.initialize();

    state = PartyVoiceState(
      isInitialized: isInitialized,
      hasPermission: hasPermission,
      connectedVoicePeers: const {},
      speakingPeers: const {},
    );

    if (!isInitialized || !hasPermission) return;

    // Listen to incoming WebSocket events
    _eventsSub = realtimeClient.events.listen((event) {
      if (event.type == 'webrtc_signal') {
        final payload = event.payload;
        final senderId = payload['senderId'] as String?;
        final type = payload['type'] as String?;
        final signal = payload['signal'];
        if (senderId != null && type != null && signal != null) {
          _manager?.handleSignal(senderId, type, signal);
        }
      } else if (event.type == 'voice_state_changed') {
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
      } else if (event.type == 'member_joined') {
        final payload = event.payload;
        final joinedUserId = payload['userId'] as String?;
        if (joinedUserId != null && joinedUserId != localUserId) {
          connectToPeer(joinedUserId);
        }
      } else if (event.type == 'member_left') {
        final payload = event.payload;
        final leftUserId = payload['userId'] as String?;
        if (leftUserId != null) {
          disconnectPeer(leftUserId);
        }
      }
    });

    // Auto-connect to existing room members
    final room = ref.read(partySessionProvider).room;
    if (room != null) {
      for (final member in room.members) {
        if (member.userId != localUserId) {
          connectToPeer(member.userId);
        }
      }
    }
  }

  /// PTT toggle: set local mic state and notify room.
  void setMicEnabled(bool enabled) {
    _manager?.setMicEnabled(enabled);
    state = state.copyWith(isMicEnabled: enabled);

    final sessionNotifier = ref.read(partySessionProvider.notifier);
    sessionNotifier.realtimeClient?.sendVoiceState(speaking: enabled);
  }

  /// Initiate offer to a peer.
  Future<void> connectToPeer(String peerId) async {
    await _manager?.connectToPeer(peerId, createOffer: true);
  }

  /// Peer disconnected.
  Future<void> disconnectPeer(String peerId) async {
    await _manager?.handlePeerLeft(peerId);
  }
}
