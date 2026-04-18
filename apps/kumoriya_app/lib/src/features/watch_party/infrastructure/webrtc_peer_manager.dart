import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../application/models/p2p_message.dart';
import 'signaling_client.dart';
import 'party_debug_logger.dart';

/// Callback when a P2P message arrives on any DataChannel.
typedef OnP2PMessage = void Function(String peerId, P2PMessage message);

/// Callback when a peer fully connects or disconnects.
typedef OnPeerStateChange = void Function(String peerId, bool connected);

/// Debug log helper for WebRTC signaling.
const bool _watchPartyVerboseLogs = bool.fromEnvironment(
  'WATCH_PARTY_VERBOSE_LOGS',
  defaultValue: false,
);

void _rtcLog(String msg) {
  if (!_watchPartyVerboseLogs) return;
  dev.log('[WebRTC] $msg', name: 'Party');
}

void _rtcDebug(String msg) {
  if (!_watchPartyVerboseLogs) return;
  PartyDebugLogger.log('WebRTC', msg);
}

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

  // Public STUN + free TURN (OpenRelay) for NAT traversal.
  // In production these should be replaced with a TURN service
  // (e.g. Twilio, Coturn self-hosted) for reliable connectivity.
  static const _rtcConfig = <String, dynamic>{
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // OpenRelay free tier — rate-limited but works for <4 peers.
      {
        'urls': [
          'turn:relay1.expressturn.com:3478',
          'turn:relay2.expressturn.com:3478',
        ],
        'username': 'turn',
        'credential': 'turn',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all', // Use both STUN and TURN
  };

  /// IDs of currently connected peers.
  Iterable<String> get connectedPeers =>
      _peers.entries.where((e) => e.value.connected).map((e) => e.key);

  /// Start listening for signaling events and establish P2P connections.
  void connect(SignalingClient signaling) {
    _rtcLog('connect() — starting signaling listener');
    _rtcDebug('connect() — localUserId=$localUserId');
    _signaling = signaling;
    _signalSub = signaling.messages.listen(_onSignal);
    _rtcDebug('signal subscription attached');
  }

  /// Send a [P2PMessage] to all connected peers.
  void broadcast(P2PMessage message) {
    final encoded = message.encode();
    int sent = 0;
    int failed = 0;
    int skipped = 0;
    final total = _peers.length;

    // Track skip reasons for diagnostic logging
    final skipReasons = <String, int>{};

    for (final entry in _peers.entries) {
      final peerId = entry.key;
      final peerEntry = entry.value;

      // Check eligibility for send
      if (!peerEntry.connected) {
        skipped++;
        final reason =
            'not_connected(state=${peerEntry.pc.connectionState?.name ?? "unknown"})';
        skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
        _rtcDebug('broadcast: skipping peer $peerId — reason: $reason');
        continue;
      }

      if (peerEntry.dataChannel == null) {
        skipped++;
        const reason = 'no_datachannel';
        skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
        _rtcDebug('broadcast: skipping peer $peerId — reason: $reason');
        continue;
      }

      final dcState = peerEntry.dataChannel!.state;
      if (dcState != RTCDataChannelState.RTCDataChannelOpen) {
        skipped++;
        final reason =
            'datachannel_not_open(state=${dcState?.name ?? "unknown"})';
        skipReasons[reason] = (skipReasons[reason] ?? 0) + 1;
        _rtcDebug('broadcast: skipping peer $peerId — reason: $reason');
        continue;
      }

      // Attempt to send
      try {
        peerEntry.dataChannel!.send(RTCDataChannelMessage(encoded));
        sent++;
        _rtcDebug('broadcast: successfully sent to peer $peerId');
      } catch (e) {
        failed++;
        _rtcLog('broadcast: failed to send to peer $peerId: $e');
        PartyDebugLogger.log(
          'Broadcast-SendFailed',
          'peerId=$peerId error=$e messageType=${message.type.name}',
        );
      }
    }

    // Log detailed broadcast metrics
    final skipReasonsStr = skipReasons.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');

    _rtcLog(
      'broadcast: total=$total sent=$sent failed=$failed skipped=$skipped type=${message.type.name}',
    );
    PartyDebugLogger.log(
      'Broadcast-Metrics',
      'total=$total sent=$sent failed=$failed skipped=$skipped type=${message.type.name} skipReasons={$skipReasonsStr}',
    );

    // Log warning if no peers received the message
    if (sent == 0 && total > 0) {
      _rtcLog(
        'broadcast: WARNING — no peers received message (type=${message.type.name})',
      );
      PartyDebugLogger.log(
        'Broadcast-NoRecipients',
        'total=$total failed=$failed skipped=$skipped type=${message.type.name} skipReasons={$skipReasonsStr}',
      );
    }
  }

  /// Send a [P2PMessage] to a specific peer.
  void sendTo(String peerId, P2PMessage message) {
    final entry = _peers[peerId];
    if (entry != null && entry.connected && entry.dataChannel != null) {
      entry.dataChannel!.send(RTCDataChannelMessage(message.encode()));
      _rtcDebug('sendTo: sent to $peerId type=${message.type.name}');
    } else {
      _rtcDebug(
        'sendTo: peer $peerId not connected — entry=${entry != null} connected=${entry?.connected} dc=${entry?.dataChannel != null}',
      );
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

  /// Signaling event routing — logs every message received from the server.
  void _onSignal(SignalEnvelope envelope) {
    _rtcLog('_onSignal: type=${envelope.type} from=${envelope.from}');
    _rtcDebug(
      '_onSignal: type=${envelope.type} from=${envelope.from} payloadKeys=${envelope.payload.keys.join(",")}',
    );
    if (envelope.isRoomState) {
      _handleRoomState(envelope);
    } else if (envelope.isPeerJoined) {
      unawaited(_handlePeerJoined(envelope));
    } else if (envelope.isPeerLeft) {
      _handlePeerLeft(envelope);
    } else if (envelope.isOffer) {
      unawaited(_handleOffer(envelope));
    } else if (envelope.isAnswer) {
      unawaited(_handleAnswer(envelope));
    } else if (envelope.isCandidate) {
      unawaited(_handleCandidate(envelope));
    } else {
      _rtcLog('_onSignal: unhandled type=${envelope.type}');
      _rtcDebug(
        '_onSignal: unhandled type=${envelope.type} fullPayload=${envelope.payload}',
      );
    }
  }

  /// On room_state we learn about existing peers and send offers to each.
  Future<void> _handleRoomState(SignalEnvelope envelope) async {
    final peers = envelope.payload['peers'] as List? ?? [];
    _rtcLog('room_state: ${peers.length} existing peer(s)');
    _rtcDebug('room_state: ${peers.length} existing peer(s) — peers=$peers');
    for (final peer in peers) {
      // Server may send peer IDs as plain strings or as objects with userId.
      final String peerId;
      if (peer is Map) {
        peerId = peer['userId'] as String;
      } else {
        peerId = peer as String;
      }
      if (peerId == localUserId) {
        _rtcLog('room_state: skipping self ($peerId)');
        _rtcDebug('room_state: skipping self ($peerId)');
        continue;
      }

      // We are the new joiner → we initiate offers to all existing peers.
      _rtcLog('room_state: creating offer to existing peer: $peerId');
      _rtcDebug('room_state: creating offer to existing peer: $peerId');
      await _createOfferTo(peerId);
    }
  }

  /// On peer_joined we learn a NEW peer connected to the room.
  /// In a full-mesh topology, EVERY existing peer must create an offer
  /// to the newcomer so bidirectional DataChannels are established.
  Future<void> _handlePeerJoined(SignalEnvelope envelope) async {
    final peerId = envelope.payload['userId'] as String?;
    if (peerId == null || peerId == localUserId) {
      _rtcLog(
        'peer_joined: ignoring (peerId=$peerId, localUserId=$localUserId)',
      );
      _rtcDebug(
        'peer_joined: ignoring (peerId=$peerId, localUserId=$localUserId)',
      );
      return;
    }

    _rtcLog('peer_joined: $peerId — creating offer');
    _rtcDebug('peer_joined: $peerId — creating offer');
    await _createOfferTo(peerId);
  }

  /// Create an offer to a peer (we are the initiator).
  Future<void> _createOfferTo(String peerId) async {
    _rtcLog('_createOfferTo($peerId) — start');
    _rtcDebug('_createOfferTo($peerId) — start');
    final entry = await _getOrCreatePeer(peerId, createDataChannel: true);

    _rtcLog('_createOfferTo($peerId) — creating SDP offer');
    _rtcDebug('_createOfferTo($peerId) — creating SDP offer');
    final offer = await entry.pc.createOffer();
    await entry.pc.setLocalDescription(offer);
    _rtcLog('_createOfferTo($peerId) — local description set, sending offer');
    _rtcDebug('_createOfferTo($peerId) — local description set, sending offer');

    _signaling?.sendOffer(peerId, {'sdp': offer.sdp, 'type': offer.type});
    _rtcDebug('_createOfferTo($peerId) — offer sent via signaling');
  }

  /// Handle an incoming SDP offer — create answer.
  Future<void> _handleOffer(SignalEnvelope envelope) async {
    final peerId = envelope.from;
    if (peerId == null) return;
    _rtcLog('_handleOffer from $peerId');
    _rtcDebug('_handleOffer from $peerId');

    final entry = await _getOrCreatePeer(peerId, createDataChannel: false);
    _rtcDebug('_handleOffer: peer entry created/retrieved');

    await entry.pc.setRemoteDescription(
      RTCSessionDescription(
        envelope.payload['sdp'] as String?,
        envelope.payload['type'] as String?,
      ),
    );
    entry.hasRemoteDescription = true;
    _rtcLog('_handleOffer from $peerId — remote description set');
    _rtcDebug('_handleOffer from $peerId — remote description set');

    // Flush buffered candidates now that remote description is set.
    for (final c in entry.bufferedCandidates) {
      await entry.pc.addCandidate(c);
    }
    entry.bufferedCandidates.clear();
    _rtcDebug('_handleOffer: buffered candidates flushed');

    final answer = await entry.pc.createAnswer();
    await entry.pc.setLocalDescription(answer);
    _rtcLog('_handleOffer from $peerId — answer sent');
    _rtcDebug('_handleOffer from $peerId — answer created and sent');

    _signaling?.sendAnswer(peerId, {'sdp': answer.sdp, 'type': answer.type});
  }

  /// Handle an incoming SDP answer.
  Future<void> _handleAnswer(SignalEnvelope envelope) async {
    final peerId = envelope.from;
    if (peerId == null) return;
    _rtcLog('_handleAnswer from $peerId');
    _rtcDebug('_handleAnswer from $peerId');

    final entry = _peers[peerId];
    if (entry == null) {
      _rtcDebug('_handleAnswer: NO peer entry for $peerId');
      return;
    }

    await entry.pc.setRemoteDescription(
      RTCSessionDescription(
        envelope.payload['sdp'] as String?,
        envelope.payload['type'] as String?,
      ),
    );
    entry.hasRemoteDescription = true;
    _rtcLog('_handleAnswer from $peerId — remote description set');
    _rtcDebug('_handleAnswer from $peerId — remote description set');

    // Flush buffered candidates.
    for (final c in entry.bufferedCandidates) {
      await entry.pc.addCandidate(c);
    }
    entry.bufferedCandidates.clear();
    _rtcDebug('_handleAnswer: buffered candidates flushed');
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
    if (entry == null) {
      _rtcDebug('_handleCandidate: NO peer entry for $peerId');
      return;
    }

    // Buffer if remote description not yet set.
    if (!entry.hasRemoteDescription) {
      _rtcLog('_handleCandidate from $peerId — buffering (no remote desc)');
      _rtcDebug('_handleCandidate from $peerId — buffering (no remote desc)');
      entry.bufferedCandidates.add(candidate);
    } else {
      await entry.pc.addCandidate(candidate);
      _rtcDebug('_handleCandidate from $peerId — added directly');
    }
  }

  /// Handle peer leaving — close their connection.
  Future<void> _handlePeerLeft(SignalEnvelope envelope) async {
    final peerId = envelope.payload['userId'] as String?;
    if (peerId == null) return;
    _rtcLog('_handlePeerLeft: $peerId');

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
    if (_peers.containsKey(peerId)) {
      _rtcDebug('_getOrCreatePeer($peerId) — REUSING existing entry');
      return _peers[peerId]!;
    }
    _rtcLog('_getOrCreatePeer($peerId) createDataChannel=$createDataChannel');
    _rtcDebug(
      '_getOrCreatePeer($peerId) createDataChannel=$createDataChannel — CREATING new',
    );

    final pc = await createPeerConnection(_rtcConfig);
    _rtcDebug('_getOrCreatePeer($peerId) — RTCPeerConnection created');

    final entry = _PeerEntry(pc: pc);
    _peers[peerId] = entry;

    // CRITICAL: Set onDataChannel handler IMMEDIATELY after creating the peer connection
    // to prevent race condition where remote DataChannel arrives before handler is configured.
    // This must be set BEFORE any offer processing to ensure the answerer doesn't miss
    // incoming DataChannels.
    if (!createDataChannel) {
      // We are the answerer → wait for the remote peer's DataChannel.
      _rtcLog(
        '_getOrCreatePeer($peerId) — setting up DataChannel handler (answerer)',
      );
      PartyDebugLogger.log(
        'DataChannel-Handler',
        'peerId=$peerId role=answerer — onDataChannel handler configured',
      );
      pc.onDataChannel = (RTCDataChannel dc) {
        _rtcLog('onDataChannel received from $peerId, label=${dc.label}');
        PartyDebugLogger.log(
          'DataChannel-Received',
          'peerId=$peerId label=${dc.label} channelId=${dc.id} state=${dc.state?.name ?? "unknown"}',
        );
        if (entry.dataChannel != null) {
          _rtcLog(
            'onDataChannel: already has a DataChannel, ignoring duplicate',
          );
          PartyDebugLogger.log(
            'DataChannel-Duplicate',
            'peerId=$peerId label=${dc.label} — ignoring duplicate channel',
          );
          return;
        }
        entry.dataChannel = dc;
        _setupDataChannel(peerId, dc);
      };
    }

    // ICE candidate → relay to peer via signaling.
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _rtcLog('ICE candidate for $peerId');
      _signaling?.sendCandidate(peerId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // Connection state changes.
    pc.onConnectionState = (RTCPeerConnectionState state) {
      _rtcLog('peer $peerId connection state: ${state.name}');
      final connected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      final failed =
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed;

      if (connected && !entry.connected) {
        entry.connected = true;
        onPeerStateChange?.call(peerId, true);
        _rtcLog('peer $peerId marked as CONNECTED via onConnectionState');
      } else if (failed && entry.connected) {
        entry.connected = false;
        onPeerStateChange?.call(peerId, false);
        _rtcLog('peer $peerId marked as DISCONNECTED via onConnectionState');
      }
    };

    if (createDataChannel) {
      // We are the offerer → create a DataChannel immediately.
      final dc = await pc.createDataChannel(
        'party',
        RTCDataChannelInit()..ordered = true,
      );
      entry.dataChannel = dc;
      _rtcLog('_getOrCreatePeer($peerId) — created DataChannel (offerer)');
      PartyDebugLogger.log(
        'DataChannel-Created',
        'peerId=$peerId role=offerer label=${dc.label} channelId=${dc.id} state=${dc.state?.name ?? "unknown"}',
      );
      _setupDataChannel(peerId, dc);
    }

    return entry;
  }

  void _setupDataChannel(String peerId, RTCDataChannel dc) {
    _rtcLog('_setupDataChannel($peerId) — setting up handlers');
    _rtcDebug(
      '_setupDataChannel($peerId) — channel label=${dc.label} id=${dc.id}',
    );
    // Enhanced diagnostic logging for DataChannel setup
    PartyDebugLogger.log(
      'DataChannel-Setup',
      'peerId=$peerId label=${dc.label} channelId=${dc.id} initialState=${dc.state?.name ?? "unknown"}',
    );

    dc.onMessage = (RTCDataChannelMessage message) {
      if (!message.isBinary) {
        final messageSize = message.text.length;
        _rtcLog(
          '_setupDataChannel($peerId) — received text message: ${message.text.substring(0, message.text.length > 100 ? 100 : message.text.length)}...',
        );
        // Enhanced diagnostic logging for message receipt
        PartyDebugLogger.log(
          'DataChannel-Message',
          'peerId=$peerId messageSize=$messageSize bytes',
        );
        final parsed = P2PMessage.decode(message.text);
        if (parsed != null) {
          _rtcLog(
            '_setupDataChannel($peerId) — parsed message type=${parsed.type.name} from=${parsed.senderId}',
          );
          // Enhanced diagnostic logging for parsed message type
          PartyDebugLogger.log(
            'DataChannel-Message-Parsed',
            'peerId=$peerId messageType=${parsed.type.name} senderId=${parsed.senderId} size=$messageSize bytes',
          );
          onMessage?.call(peerId, parsed);
        } else {
          _rtcLog('_setupDataChannel($peerId) — FAILED to parse message');
          // Enhanced diagnostic logging for parse failure
          PartyDebugLogger.log(
            'DataChannel-Message-ParseFailed',
            'peerId=$peerId messageSize=$messageSize bytes',
          );
        }
      } else {
        _rtcLog(
          '_setupDataChannel($peerId) — received binary message, ignoring',
        );
        // Enhanced diagnostic logging for binary message
        PartyDebugLogger.log(
          'DataChannel-Message-Binary',
          'peerId=$peerId (ignored)',
        );
      }
    };

    dc.onDataChannelState = (RTCDataChannelState state) {
      _rtcLog('DataChannel $peerId state: ${state.name}');
      _rtcDebug('DataChannel $peerId state: ${state.name}');
      // Enhanced diagnostic logging for detailed state transitions
      PartyDebugLogger.log(
        'DataChannel-State',
        'peerId=$peerId label=${dc.label} channelId=${dc.id} state=${state.name}',
      );
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _peers[peerId]?.connected = true;
        _rtcLog('DataChannel $peerId OPEN — peer marked as connected');
        _rtcDebug('DataChannel $peerId OPEN — peer marked as connected');
        PartyDebugLogger.log(
          'DataChannel-Open',
          'peerId=$peerId label=${dc.label} channelId=${dc.id} — peer marked as connected',
        );
        onPeerStateChange?.call(peerId, true);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _peers[peerId]?.connected = false;
        _rtcLog('DataChannel $peerId CLOSED — peer marked as disconnected');
        _rtcDebug('DataChannel $peerId CLOSED — peer marked as disconnected');
        PartyDebugLogger.log(
          'DataChannel-Closed',
          'peerId=$peerId label=${dc.label} channelId=${dc.id} — peer marked as disconnected',
        );
        onPeerStateChange?.call(peerId, false);
      } else if (state == RTCDataChannelState.RTCDataChannelConnecting) {
        PartyDebugLogger.log(
          'DataChannel-Connecting',
          'peerId=$peerId label=${dc.label} channelId=${dc.id}',
        );
      } else if (state == RTCDataChannelState.RTCDataChannelClosing) {
        PartyDebugLogger.log(
          'DataChannel-Closing',
          'peerId=$peerId label=${dc.label} channelId=${dc.id}',
        );
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
