/// Audio kind for source episodes.
enum SourceAudioKind { sub, dub }

/// Maps a source code string to a [SourceAudioKind].
SourceAudioKind? sourceAudioKindFromCode(String? code) {
  final normalized = code?.trim().toLowerCase();
  switch (normalized) {
    case 'sub':
      return SourceAudioKind.sub;
    case 'dub':
    case 'lat':
    case 'cast':
      return SourceAudioKind.dub;
    default:
      return null;
  }
}
