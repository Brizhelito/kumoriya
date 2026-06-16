/// Represents the client-side state of PTT voice chat for the watch party.
final class PartyVoiceState {
  const PartyVoiceState({
    this.isInitialized = false,
    this.isMicEnabled = false,
    this.hasPermission = false,
    this.connectedVoicePeers = const <String>{},
    this.speakingPeers = const <String>{},
    this.peersWithAudio = const <String>{},
    this.isConnecting = false,
  });

  /// Whether `getUserMedia` has finished initializing.
  final bool isInitialized;

  /// Whether the local microphone is currently unmuted (speaking).
  final bool isMicEnabled;

  /// Whether runtime permission to record audio has been granted.
  final bool hasPermission;

  /// IDs of peers with whom we have established an active WebRTC voice connection.
  final Set<String> connectedVoicePeers;

  /// IDs of peers currently speaking (broadcasting voice).
  final Set<String> speakingPeers;

  /// IDs of peers whose remote audio stream we have received.
  final Set<String> peersWithAudio;

  /// Whether ICE connection is currently negotiating.
  final bool isConnecting;

  /// Whether voice chat is fully set up and ready to use locally.
  bool get isAvailable => isInitialized && hasPermission;

  PartyVoiceState copyWith({
    bool? isInitialized,
    bool? isMicEnabled,
    bool? hasPermission,
    Set<String>? connectedVoicePeers,
    Set<String>? speakingPeers,
    Set<String>? peersWithAudio,
    bool? isConnecting,
  }) {
    return PartyVoiceState(
      isInitialized: isInitialized ?? this.isInitialized,
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      connectedVoicePeers: connectedVoicePeers ?? this.connectedVoicePeers,
      speakingPeers: speakingPeers ?? this.speakingPeers,
      peersWithAudio: peersWithAudio ?? this.peersWithAudio,
      isConnecting: isConnecting ?? this.isConnecting,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PartyVoiceState &&
        other.isInitialized == isInitialized &&
        other.isMicEnabled == isMicEnabled &&
        other.hasPermission == hasPermission &&
        other.connectedVoicePeers == connectedVoicePeers &&
        other.speakingPeers == speakingPeers &&
        other.peersWithAudio == peersWithAudio &&
        other.isConnecting == isConnecting;
  }

  @override
  int get hashCode {
    return Object.hash(
      isInitialized,
      isMicEnabled,
      hasPermission,
      connectedVoicePeers,
      speakingPeers,
      peersWithAudio,
      isConnecting,
    );
  }
}
