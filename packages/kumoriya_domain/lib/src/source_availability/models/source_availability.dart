enum SourceAvailabilityStatus { available, unavailable, error }

final class SourceAvailabilitySummary {
  const SourceAvailabilitySummary({
    required this.playableSources,
    required this.status,
  });

  final List<String> playableSources;
  final SourceAvailabilityStatus status;
}
