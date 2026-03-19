final class NexusVariantPathMetadata {
  const NexusVariantPathMetadata({required this.variant, required this.track});

  final String variant;
  final int track;
}

final class NexusMasterManifest {
  const NexusMasterManifest({
    required this.audioEntries,
    required this.streamEntries,
  });

  final List<NexusAudioTrackEntry> audioEntries;
  final List<NexusVideoStreamEntry> streamEntries;
}

final class NexusAudioTrackEntry {
  const NexusAudioTrackEntry({
    required this.originalLine,
    required this.groupId,
    required this.uri,
    required this.metadata,
  });

  final String originalLine;
  final String groupId;
  final Uri uri;
  final NexusVariantPathMetadata metadata;
}

final class NexusVideoStreamEntry {
  const NexusVideoStreamEntry({
    required this.infoLine,
    required this.uri,
    required this.audioGroupId,
    required this.qualityLabel,
    required this.metadata,
  });

  final String infoLine;
  final Uri uri;
  final String? audioGroupId;
  final String qualityLabel;
  final NexusVariantPathMetadata metadata;
}

final class NexusHlsManifestParser {
  const NexusHlsManifestParser();

  NexusMasterManifest parseMasterManifest({
    required String content,
    required Uri baseUri,
  }) {
    final audioEntries = <NexusAudioTrackEntry>[];
    final streamEntries = <NexusVideoStreamEntry>[];
    final lines = content.split('\n');

    for (var index = 0; index < lines.length; index++) {
      final rawLine = lines[index];
      final line = rawLine.trim();
      if (line.startsWith('#EXT-X-MEDIA')) {
        final attrs = _parseAttributes(line);
        if (attrs['TYPE'] != 'AUDIO') {
          continue;
        }

        final groupId = attrs['GROUP-ID']?.trim() ?? '';
        final uriValue = attrs['URI']?.trim() ?? '';
        if (groupId.isEmpty || uriValue.isEmpty) {
          continue;
        }

        final uri = baseUri.resolve(uriValue);
        final metadata = parseVariantMetadata(uri);
        if (metadata == null) {
          continue;
        }

        audioEntries.add(
          NexusAudioTrackEntry(
            originalLine: rawLine,
            groupId: groupId,
            uri: uri,
            metadata: metadata,
          ),
        );
        continue;
      }

      if (!line.startsWith('#EXT-X-STREAM-INF') || index + 1 >= lines.length) {
        continue;
      }

      final uriLine = lines[index + 1].trim();
      if (uriLine.isEmpty || uriLine.startsWith('#')) {
        continue;
      }

      final uri = baseUri.resolve(uriLine);
      final metadata = parseVariantMetadata(uri);
      if (metadata == null) {
        continue;
      }

      final attrs = _parseAttributes(line);
      streamEntries.add(
        NexusVideoStreamEntry(
          infoLine: rawLine,
          uri: uri,
          audioGroupId: attrs['AUDIO']?.trim(),
          qualityLabel: _parseQualityLabel(line),
          metadata: metadata,
        ),
      );
    }

    return NexusMasterManifest(
      audioEntries: audioEntries,
      streamEntries: streamEntries,
    );
  }

  NexusVariantPathMetadata? parseVariantMetadata(Uri uri) {
    final path = uri.path;
    final match = RegExp(r'_([0-9]+)-([0-9]+)\.m3u8$').firstMatch(path);
    if (match == null) {
      return null;
    }

    return NexusVariantPathMetadata(
      variant: match.group(1)!,
      track: int.parse(match.group(2)!),
    );
  }

  Map<String, String> _parseAttributes(String line) {
    final attrs = <String, String>{};
    for (final match in RegExp(
      r'([A-Z0-9-]+)=("[^"]*"|[^,]+)',
    ).allMatches(line)) {
      final key = match.group(1)!;
      final value = match.group(2)!.trim();
      attrs[key] = value.startsWith('"') && value.endsWith('"')
          ? value.substring(1, value.length - 1)
          : value;
    }
    return attrs;
  }

  String _parseQualityLabel(String line) {
    final resolutionMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
    if (resolutionMatch != null) {
      return '${resolutionMatch.group(2)}p';
    }

    final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
    if (bandwidthMatch != null) {
      final bps = int.tryParse(bandwidthMatch.group(1)!) ?? 0;
      return _estimateResolutionFromBandwidth(bps);
    }

    return 'auto';
  }

  String _estimateResolutionFromBandwidth(int bps) {
    final kbps = bps ~/ 1000;
    if (kbps >= 8000) return '2160p';
    if (kbps >= 4000) return '1080p';
    if (kbps >= 1500) return '720p';
    if (kbps >= 800) return '480p';
    if (kbps >= 400) return '360p';
    return '240p';
  }
}
