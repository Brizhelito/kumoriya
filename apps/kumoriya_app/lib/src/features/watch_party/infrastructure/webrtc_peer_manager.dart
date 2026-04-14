import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../application/models/p2p_message.dart';
import 'signaling_client.dart';

/// Callback when a P2P message arrives on any DataChannel.
typedef OnP2PMessage = void Function(String peerId, P2PMessage message);

/// Callback when a peer fully connects or disconnects.
typedef OnPeerStateChange = void Function(String peerId, bool connected);

/// Manages WebRTC peer connections in a full-mesh topology (max 4 peers).
///
/// Lifecycle:
/// 1. Call [connect] with signaling client and user info.
/// 2. The manager listens for signaling events and creates/answers offers.
/// 3. DataChannels are created for each peer connection.
/// 4. P2P messages flow via [onMessage] callback.
/// 5. Call [dispose] to tear down all connections.
final class WebRtcPeerManager {
  WebRtcPeerManager({
    required this.localUserId,
    this.onMessage,
    this.onPeerStateChange,
  });

  final String localUserId;
  OnP2PMessage? onMessage;
  OnPeerStateChange? onPeerStateChange;

  SignalingClient? _signaling;
  StreamSubscription<SignalEnvelope>? _signalSub;

  final _peers = <String, _PeerEntry>{};

  static const _rtcConfig = <String, dynamic>{
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// IDs of currently connected peers.
  Iterable<String> get connectedPeers =>
      _peers.entries.where((e) => e.value.connected).map((e) => e.key);

  /// Start listening for signaling events and establish P2P connections.
  void connect(SignalingClient signaling) {
    _signaling = signaling;
    _signalSub = signaling.messages.listen(_onSignal);
  }

  /// Send a [P2PMessage] to all connected peers.
  void broadcast(P2PMessage message) {
    final encoded = message.encode();
    for (final entry in _peers.values) {
      if (entry.connected && entry.dataChannel != null) {
        entry.dataChannel!.send(RTCDataChannelMessage(encoded));
      }
    }
  }

  /// Send a [P2PMessage] to a specific peer.
  void sendTo(String peerId, P2PMessage message) {
    final entry = _peers[peerId];
    if (entry != null && entry.connected && entry.dataChannel != null) {
      entry.dataChannel!.send(RTCDataChannelMessage(message.encode()));
    }
  }

  /// Tear down all peer connections and signaling.
  Future<void> dispose() async {
    _signalSub?.cancel();
    _signaling = null;
    for (final entry in _peers.values) {
      entry.dataChannel?.close();
      await entry.pc.close();
    }
    _peers.clear();
  }

  // ── Signaling event routing ──

  void _onSignal(SignalEnvelope envelope) {
    if (envelope.isRoomState) {
      _handleRoomState(envelope);
    } else if (envelope.isPeerJoined) {
      // New peer joined — they will initiate offers to us.
    } else if (envelope.isPeerLeft) {
      _handlePeerLeft(envelope);
    } else if (envelope.isOffer) {
      _handleOffer(envelope);
    } else if (envelope.isAnswer) {
      _handleAnswer(envelope);
    } else if (envelope.isCandidate) {
      _handleCandidate(envelope);
    }
  }

  /// On room_state we learn about existing peers and send offers to each.
  Future<void> _handleRoomState(SignalEnvelope envelope) async {
    final peers = envelope.payload['peers'] as List? ?? [];
    for (final peer in peers) {
      // Server may send peer IDs as plain strings or as objects with userId.
      final String peerId;
      if (peer is Map) {
        peerId = peer['userId'] as String;
      } else {
        peerId = peer as String;
      }
      if (peerId == localUserId) continue;

      // We are the new joiner → we initiate offers to all existing peers.
      await _createOfferTo(peerId);
    }
  }

  /// Create an offer to a peer (we are the initiator).
  Future<void> _createOfferTo(String peerId) async {
    final entry = await _getOrCreatePeer(peerId, createDataChannel: true);

    final offer = await entry.pc.createOffer();
    await entry.pc.setLocalDescription(offer);

    _signaling?.sendOffer(peerId, {
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  /// Handle an incoming SDP offer — create answer.
  Future<void> _handleOffer(SignalEnvelope envelope) async {
    final peerId = envelope.from;
    if (peerId == null) return;

    final entry = await _getOrCreatePeer(peerId, createDataChannel: false);

    await entry.pc.setRemoteDescription(RTCSessionDescription(
      envelope.payload['sdp'] as String?,
      envelope.payload['type'] as String?,
    ));
    entry.hasRemoteDescription = true;

    // Flush buffered candidates now that remote description is set.
    for (final c in entry.bufferedCandidates) {
      await entry.pc.addCandidate(c);
    }
    entry.bufferedCandidates.clear();

    final answer = await entry.pc.createAnswer();
    await entry.pc.setLocalDescription(answer);

    _signaling?.sendAnswer(peerId, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  /// Handle an incoming SDP answer.
  Future<void> _handleAnswer(SignalEnvelope envelope) async {
    final peerId = envelope.from;
    if (peerId == null) return;

    final entry = _peers[peerId];
    if (entry == null) return;

    await entry.pc.setRemoteDescription(RTCSessionDescription(
      envelope.payload['sdp'] as String?,
      envelope.payload['type'] as String?,
    ));
    entry.hasRemoteDescription = true;

    // Flush buffered candidates.
    for (final c in entry.bufferedCandidates) {
      await entry.pc.addCandidate(c);
    }
    entry.bufferedCandidates.clear();
  }

  /// Handle an incoming ICE candidate.
  Future<void> _handleCandidate(SignalEnvelope envelope) async {
    final peerId = envelope.from;
    if (peerId == null) return;

    final candidate = RTCIceCandidate(
      envelope.payload['candidate'] as String?,
      envelope.payload['sdpMid'] as String?,
      envelope.payload['sdpMLineIndex'] as int?,
    );

    final entry = _peers[peerId];
    if (entry == null) return;

    // Buffer if remote description not yet set.
    if (!entry.hasRemoteDescription) {
      entry.bufferedCandidates.add(candidate);
    } else {
      await entry.pc.addCandidate(candidate);
    }
  }

  /// Handle peer leaving — close their connection.
  Future<void> _handlePeerLeft(SignalEnvelope envelope) async {
    final peerId = envelope.payload['userId'] as String?;
    if (peerId == null) return;

    final entry = _peers.remove(peerId);
    if (entry != null) {
      entry.dataChannel?.close();
      await entry.pc.close();
      onPeerStateChange?.call(peerId, false);
    }
  }

  // ── Peer connection lifecycle ──

  Future<_PeerEntry> _getOrCreatePeer(
    String peerId, {
    required bool createDataChannel,
  }) async {
    if (_peers.containsKey(peerId)) return _peers[peerId]!;

    final pc = await createPeerConnection(_rtcConfig);

    final entry = _PeerEntry(pc: pc);
    _peers[peerId] = entry;

    // ICE candidate → relay to peer via signaling.
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _signaling?.sendCandidate(peerId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // Connection state changes.
    pc.onConnectionState = (RTCPeerConnectionState state) {
      final connected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      final failed = state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed;

      if (connected && !entry.connected) {
        entry.connected = true;
        onPeerStateChange?.call(peerId, true);
      } else if (failed && entry.connected) {
        entry.connected = false;
        onPeerStateChange?.call(peerId, false);
      }
    };

    if (createDataChannel) {
      // We are the offerer → create a DataChannel.
      final dc = await pc.createDataChannel(
        'party',
        RTCDataChannelInit()..ordered = true,
      );
      entry.dataChannel = dc;
      _setupDataChannel(peerId, dc);
    } else {
      // We are the answerer → receive the DataChannel.
      pc.onDataChannel = (RTCDataChannel dc) {
        entry.dataChannel = dc;
        _setupDataChannel(peerId, dc);
      };
    }

    return entry;
  }

  void _setupDataChannel(String peerId, RTCDataChannel dc) {
    dc.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) {
        final parsed = P2PMessage.decode(message.text);
        if (parsed != null) {
          onMessage?.call(peerId, parsed);
        }
      }
    };

    dc.onDataChannelState = (RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _peers[peerId]?.connected = true;
        onPeerStateChange?.call(peerId, true);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _peers[peerId]?.connected = false;
        onPeerStateChange?.call(peerId, false);
      }
    };
  }
}

class _PeerEntry {
  _PeerEntry({required this.pc});

  final RTCPeerConnection pc;
  RTCDataChannel? dataChannel;
  bool connected = false;
  bool hasRemoteDescription = false;
  final bufferedCandidates = <RTCIceCandidate>[];
}
