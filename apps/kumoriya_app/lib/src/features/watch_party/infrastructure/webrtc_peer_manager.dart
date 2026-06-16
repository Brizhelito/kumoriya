import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'party_debug_logger.dart';

/// Callback when a peer connection state changes.
typedef OnPeerVoiceStateChange = void Function(String peerId, bool connected);

/// Callback when a remote audio stream is added.
typedef OnRemoteStream = void Function(String peerId, MediaStream stream);

const bool _watchPartyVerboseLogs = bool.fromEnvironment(
  'WATCH_PARTY_VERBOSE_LOGS',
  defaultValue: false,
);

void _voiceLog(String msg) {
  if (!_watchPartyVerboseLogs) return;
  dev.log('[VoiceRTC] $msg', name: 'PartyVoice');
}

void _voiceDebug(String msg) {
  if (!_watchPartyVerboseLogs) return;
  PartyDebugLogger.log('VoiceRTC', msg);
}

/// Manages WebRTC audio-only peer connections in a full-mesh topology (max 4 peers).
final class VoicePeerManager {
  VoicePeerManager({
    required this.localUserId,
    required this.sendSignal,
    this.onPeerStateChange,
    this.onRemoteStream,
  });

  final String localUserId;

  /// Callback to send signaling message via WebSocket v2.
  final void Function(String targetUserId, String type, Object? signal)
  sendSignal;

  /// Triggered when a peer voice connection is established or lost.
  OnPeerVoiceStateChange? onPeerStateChange;

  /// Triggered when a remote stream starts playing.
  OnRemoteStream? onRemoteStream;

  MediaStream? _localStream;
  bool _micEnabled = false;
  final _peers = <String, _VoicePeerEntry>{};

  static const _rtcConfig = <String, dynamic>{
    'iceServers': [
      // Google STUN (low-latency, globally distributed)
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Cloudflare STUN (reliable fallback, no auth needed)
      {'urls': 'stun:stun.cloudflare.com:3478'},
      // Twilio STUN (additional geographic diversity)
      {'urls': 'stun:global.stun.twilio.com:3478'},
      // ExpressTURN UDP (relay — essential for symmetric NAT / VPN)
      {
        'urls': [
          'turn:relay1.expressturn.com:3478',
          'turn:relay2.expressturn.com:3478',
        ],
        'username': 'turn',
        'credential': 'turn',
      },
      // ExpressTURN TLS (punches through restrictive firewalls / VPN)
      {
        'urls': [
          'turns:relay1.expressturn.com:5349',
          'turns:relay2.expressturn.com:5349',
        ],
        'username': 'turn',
        'credential': 'turn',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
  };

  bool get isMicEnabled => _micEnabled;

  /// Acquire microphone stream (initially muted for PTT).
  Future<bool> initialize({bool acquireMic = false}) async {
    _voiceLog('Initializing VoicePeerManager');
    if (acquireMic) {
      return await acquireMicrophone();
    }
    return true;
  }

  Future<bool> acquireMicrophone() async {
    if (_localStream != null) return true;
    _voiceLog('Initializing local audio stream');
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      // Mute local tracks by default for Push-to-Talk
      _setLocalMuted(!_micEnabled);
      _voiceLog('Local audio stream initialized successfully');

      // Attach to existing peer connections by replacing the track
      final track = _localStream!.getAudioTracks().first;
      for (final entry in _peers.values) {
        final senders = await entry.pc.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'audio' || sender.track == null) {
            await sender.replaceTrack(track);
            break;
          }
        }
      }

      return true;
    } catch (e) {
      _voiceLog('Failed to acquire microphone: $e');
      _voiceDebug('microphone_init_failed error=$e');
      return false;
    }
  }

  /// Toggle local mic mute state (PTT).
  void setMicEnabled(bool enabled) {
    if (_localStream == null) return;
    _micEnabled = enabled;
    _setLocalMuted(!enabled);
    _voiceLog('PTT state changed: micEnabled=$enabled');
  }

  void _setLocalMuted(bool muted) {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !muted;
    }
  }

  /// Tear down all connections and release the microphone.
  Future<void> dispose() async {
    _voiceLog('Disposing VoicePeerManager');
    for (final entry in _peers.values) {
      await entry.pc.close();
    }
    _peers.clear();

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
      _localStream = null;
    }
  }

  /// Dispatch an incoming signaling message to the correct peer connection.
  Future<void> handleSignal(
    String senderId,
    String type,
    Object? signal,
  ) async {
    _voiceLog('Received signal: type=$type from=$senderId');
    if (senderId == localUserId) return;

    if (type == 'offer') {
      await _handleOffer(senderId, signal);
    } else if (type == 'answer') {
      await _handleAnswer(senderId, signal);
    } else if (type == 'ice-candidate') {
      await _handleCandidate(senderId, signal);
    }
  }

  /// Initiate a connection to a peer by sending an SDP offer.
  ///
  /// If the existing peer connection is in a terminal state (failed /
  /// disconnected / closed), it is torn down and recreated so the new
  /// offer goes through a fresh RTCPeerConnection — this fixes the
  /// "stale peer" bug where re-joining members could not connect.
  Future<void> connectToPeer(String peerId, {required bool createOffer}) async {
    if (peerId == localUserId) return;
    _voiceLog('Connecting to peer: $peerId (createOffer=$createOffer)');

    // If a stale/dead connection exists for this peer, tear it down first.
    // Check both our tracking flag AND the native connection state, since
    // on Android the onConnectionState callback sometimes doesn't fire
    // for transient disconnections.
    final stale = _peers[peerId];
    if (stale != null) {
      final nativeState = await stale.pc.getConnectionState();
      final isDead =
          !stale.connected ||
          nativeState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          nativeState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          nativeState == RTCPeerConnectionState.RTCPeerConnectionStateClosed;
      if (isDead) {
        _voiceLog(
          'Removing stale peer entry for $peerId '
          '(connected=${stale.connected}, native=${nativeState?.name ?? 'null'})',
        );
        try {
          await stale.pc.close();
        } catch (_) {}
        _peers.remove(peerId);
      }
    }

    final entry = await _getOrCreatePeer(peerId);

    if (createOffer) {
      _voiceLog('Creating SDP offer for $peerId');
      final offer = await entry.pc.createOffer();
      await entry.pc.setLocalDescription(offer);

      sendSignal(peerId, 'offer', {'sdp': offer.sdp, 'type': offer.type});
    }
  }

  /// Remove a peer when they leave the room.
  Future<void> handlePeerLeft(String peerId) async {
    _voiceLog('Peer left: $peerId');
    final entry = _peers.remove(peerId);
    if (entry != null) {
      await entry.pc.close();
      onPeerStateChange?.call(peerId, false);
    }
  }

  // ── Signaling Helpers ──

  Future<void> _handleOffer(String peerId, Object? signal) async {
    if (signal is! Map) return;
    final sdp = signal['sdp'] as String?;
    final sdpType = signal['type'] as String?;
    if (sdp == null || sdp.isEmpty || sdpType == null || sdpType.isEmpty) {
      _voiceLog(
        'Invalid offer signal from $peerId: '
        'sdp=${sdp != null ? 'present' : 'null'}, type=$sdpType',
      );
      return;
    }

    final entry = await _getOrCreatePeer(peerId);
    await entry.pc.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
    entry.hasRemoteDescription = true;

    // Delay to let the signaling thread fully process setRemoteDescription
    // before adding candidates. Prevents native race condition (SIGABRT).
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Flush buffered candidates
    for (final candidate in entry.bufferedCandidates) {
      await entry.pc.addCandidate(candidate);
    }
    entry.bufferedCandidates.clear();

    final answer = await entry.pc.createAnswer();
    await entry.pc.setLocalDescription(answer);

    sendSignal(peerId, 'answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _handleAnswer(String peerId, Object? signal) async {
    if (signal is! Map) return;
    final sdp = signal['sdp'] as String?;
    final sdpType = signal['type'] as String?;
    if (sdp == null || sdp.isEmpty || sdpType == null || sdpType.isEmpty) {
      _voiceLog(
        'Invalid answer signal from $peerId: '
        'sdp=${sdp != null ? 'present' : 'null'}, type=$sdpType',
      );
      return;
    }

    final entry = _peers[peerId];
    if (entry == null) return;

    await entry.pc.setRemoteDescription(RTCSessionDescription(sdp, sdpType));
    entry.hasRemoteDescription = true;

    // Delay to let the signaling thread fully process setRemoteDescription
    // before adding candidates. Prevents native race condition (SIGABRT).
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Flush buffered candidates
    for (final candidate in entry.bufferedCandidates) {
      await entry.pc.addCandidate(candidate);
    }
    entry.bufferedCandidates.clear();
  }

  Future<void> _handleCandidate(String peerId, Object? signal) async {
    if (signal is! Map) return;
    final candidateStr = signal['candidate'] as String?;
    final sdpMid = signal['sdpMid'] as String?;
    // Guard: JSON may decode 0 as 0.0 (double), so coerce via num.
    final rawIndex = signal['sdpMLineIndex'];
    final sdpMLineIndex = rawIndex is int
        ? rawIndex
        : (rawIndex is num ? rawIndex.toInt() : 0);
    // Guard: null/empty candidate string is useless.
    if (candidateStr == null || candidateStr.isEmpty) return;
    // Guard: null or empty sdpMid crashes native JNI NewStringUTF
    // (SIGABRT). A candidate without a valid media section reference
    // cannot be applied, so skip it entirely.
    if (sdpMid == null || sdpMid.isEmpty) {
      _voiceLog('Skipping ICE candidate from $peerId: empty sdpMid');
      return;
    }

    _voiceLog(
      'Handling ICE candidate from $peerId: sdpMid=$sdpMid, '
      'mline=$sdpMLineIndex',
    );
    final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);
    final entry = _peers[peerId];
    if (entry == null) return;

    if (!entry.hasRemoteDescription) {
      entry.bufferedCandidates.add(candidate);
    } else {
      await entry.pc.addCandidate(candidate);
    }
  }

  // ── Peer connection initialization ──

  /// Perform an ICE restart on an existing peer connection.
  ///
  /// Creates a new offer with `iceRestart: true`, which causes the browser
  /// to re-gather ICE candidates (potentially discovering new relay paths)
  /// while keeping the existing SDP negotiation. This is the standard
  /// WebRTC recovery mechanism for transient network failures.
  Future<void> _iceRestart(String peerId, _VoicePeerEntry entry) async {
    try {
      entry.hasRemoteDescription = false;
      entry.bufferedCandidates.clear();
      final offer = await entry.pc.createOffer({'iceRestart': true});
      await entry.pc.setLocalDescription(offer);
      sendSignal(peerId, 'offer', {'sdp': offer.sdp, 'type': offer.type});
      _voiceLog('ICE restart offer sent to $peerId');
    } catch (e) {
      _voiceLog('ICE restart failed for $peerId: $e');
      _voiceDebug('ice_restart_error peer=$peerId error=$e');
    }
  }

  Future<_VoicePeerEntry> _getOrCreatePeer(String peerId) async {
    final existing = _peers[peerId];
    if (existing != null) return existing;

    _voiceLog('Creating RTCPeerConnection for $peerId');
    final pc = await createPeerConnection(_rtcConfig);
    final entry = _VoicePeerEntry(pc: pc);
    _peers[peerId] = entry;

    // Attach local audio track if available
    final localStream = _localStream;
    if (localStream != null) {
      for (final track in localStream.getAudioTracks()) {
        await pc.addTrack(track, localStream);
      }
    } else {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
    }

    // Handle ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      final candidateStr = candidate.candidate;
      final mid = candidate.sdpMid;
      // Skip candidates with null/empty sdpMid or candidate string.
      // They cannot be applied by the remote peer and may trigger
      // native JNI crashes in flutter_webrtc (SIGABRT in NewStringUTF).
      if (candidateStr == null || candidateStr.isEmpty) return;
      if (mid == null || mid.isEmpty) {
        _voiceLog('Skipping local ICE candidate for $peerId: empty sdpMid');
        return;
      }
      sendSignal(peerId, 'ice-candidate', {
        'candidate': candidateStr,
        'sdpMid': mid,
        'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
      });
    };

    // Handle remote streams
    pc.onAddStream = (MediaStream stream) {
      _voiceLog('Remote stream added from $peerId');
      onRemoteStream?.call(peerId, stream);
    };

    pc.onTrack = (RTCTrackEvent event) {
      _voiceLog('Remote track added from $peerId');
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(peerId, event.streams.first);
      }
    };

    // Handle connection state changes
    pc.onConnectionState = (RTCPeerConnectionState state) {
      _voiceLog('Connection state for $peerId changed to: ${state.name}');
      _voiceDebug('conn_state peer=$peerId state=${state.name}');
      final connected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      final failed =
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed;

      if (connected && !entry.connected) {
        entry.connected = true;
        entry.iceRestartAttempted = false; // reset on success
        onPeerStateChange?.call(peerId, true);
      } else if (failed && entry.connected) {
        entry.connected = false;
        onPeerStateChange?.call(peerId, false);

        // Attempt a single ICE restart before giving up. This re-gathers
        // candidates and can recover from transient NAT/VPN failures that
        // are common on Linux desktop.
        if (!entry.iceRestartAttempted) {
          entry.iceRestartAttempted = true;
          _voiceLog('Attempting ICE restart for $peerId');
          _voiceDebug('ice_restart peer=$peerId');
          _iceRestart(peerId, entry);
        } else {
          _voiceLog(
            'ICE restart already attempted for $peerId — closing stale pc',
          );
          _voiceDebug('ice_restart_exhausted peer=$peerId');
          // Remove the dead entry so connectToPeer creates a fresh one.
          _peers.remove(peerId);
          try {
            pc.close();
          } catch (_) {}
        }
      }
    };

    return entry;
  }
}

class _VoicePeerEntry {
  _VoicePeerEntry({required this.pc});

  final RTCPeerConnection pc;
  bool connected = false;
  bool hasRemoteDescription = false;
  bool iceRestartAttempted = false;
  final bufferedCandidates = <RTCIceCandidate>[];
}

/// Legacy stub class to satisfy compilation of unused PartySyncEngine.
class WebRtcPeerManager {
  WebRtcPeerManager({
    required this.localUserId,
    this.onMessage,
    this.onPeerStateChange,
  });

  final String localUserId;
  dynamic onMessage;
  dynamic onPeerStateChange;

  void connect(dynamic signaling) {}
  void broadcast(dynamic message) {}
  void sendTo(String peerId, dynamic message) {}
  Future<void> dispose() async {}
}
