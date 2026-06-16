import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/voice_state.dart';
import '../../infrastructure/webrtc_peer_manager.dart';
import 'party_providers.dart';

const bool _watchPartyVerboseLogs = bool.fromEnvironment(
  'WATCH_PARTY_VERBOSE_LOGS',
  defaultValue: false,
);

void _voiceLog(String msg) {
  if (!_watchPartyVerboseLogs) return;
  dev.log('[VoiceRTC] $msg', name: 'PartyVoice');
}

final voiceSessionProvider =
    NotifierProvider<VoiceSessionNotifier, PartyVoiceState>(
      VoiceSessionNotifier.new,
    );

class VoiceSessionNotifier extends Notifier<PartyVoiceState> {
  VoicePeerManager? _manager;
  StreamSubscription? _eventsSub;

  final _renderers = <String, RTCVideoRenderer>{};

  // Tracks whether the event listener + manager are wired up (no mic yet).
  bool _isWired = false;

  @override
  PartyVoiceState build() {
    ref.onDispose(() {
      _eventsSub?.cancel();
      _manager?.dispose();
      for (final renderer in _renderers.values) {
        renderer.srcObject = null;
        renderer.dispose();
      }
      _renderers.clear();
    });
    return const PartyVoiceState(peersWithAudio: <String>{});
  }

  // ── Public surface ──────────────────────────────────────────────────────────

  /// Called by the party session when the room connects.
  /// Wires up event listeners passively without requesting mic permission.
  void wireOnly(String localUserId) {
    _wireEvents(localUserId);
  }

  /// Called by PTT button on first interaction.
  /// Requests mic permission and acquires the stream.
  /// Returns true if voice is ready to use.
  Future<bool> activate(String localUserId) async {
    _wireEvents(localUserId);

    // Request mic permission — only on mobile platforms where it is supported.
    bool granted = true;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final status = await Permission.microphone.request();
      granted = status.isGranted;
    }

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
    _disposeRenderer(peerId);
    final connected = Set<String>.from(state.connectedVoicePeers);
    final speaking = Set<String>.from(state.speakingPeers);
    final peersAudio = Set<String>.from(state.peersWithAudio);

    connected.remove(peerId);
    speaking.remove(peerId);
    peersAudio.remove(peerId);

    state = state.copyWith(
      connectedVoicePeers: connected,
      speakingPeers: speaking,
      peersWithAudio: peersAudio,
    );
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
        if (!connected) {
          _disposeRenderer(peerId);
        }
        final peers = Set<String>.from(state.connectedVoicePeers);
        if (connected) {
          peers.add(peerId);
        } else {
          peers.remove(peerId);
        }
        state = state.copyWith(connectedVoicePeers: peers);
      },
      onRemoteStream: (peerId, stream) {
        // Remote audio stream received - play it
        _voiceLog('Playing remote stream from $peerId');

        // flutter_webrtc on Desktop requires attaching the stream to a renderer
        // for it to route the audio correctly to the OS mixer.
        _setupRenderer(peerId, stream);

        final peers = Set<String>.from(state.peersWithAudio);
        peers.add(peerId);
        state = state.copyWith(peersWithAudio: peers);
      },
    );

    _eventsSub = realtimeClient.events.listen((event) {
      switch (event.type) {
        case 'webrtc_signal':
          final payload = event.payload;
          final senderId = event.sender ?? payload['senderId'] as String?;
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
          final memberRaw = payload['member'];
          final joinedUserId =
              (memberRaw is Map ? memberRaw['userId'] : payload['userId'])
                  as String?;
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

  Future<void> _setupRenderer(String peerId, MediaStream stream) async {
    if (_renderers.containsKey(peerId)) {
      _renderers[peerId]!.srcObject = stream;
      return;
    }
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    _renderers[peerId] = renderer;
  }

  void _disposeRenderer(String peerId) {
    final renderer = _renderers.remove(peerId);
    if (renderer != null) {
      renderer.srcObject = null;
      renderer.dispose();
    }
  }
}
