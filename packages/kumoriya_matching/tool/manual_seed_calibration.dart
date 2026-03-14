import 'dart:io';

import 'src/manual_seed_support.dart';

void main(List<String> args) {
  final datasetPath = args.isEmpty ? null : args.first;
  final report = evaluateManualSeedDataset(datasetPath: datasetPath);
  stdout.writeln(formatCalibrationReport(report));

  if (report.queryUnsafeAutoMatches > 0) {
    stderr.writeln(
      'Unsafe query-level auto-matches detected: ${report.queryUnsafeAutoMatches}',
    );
    exitCode = 1;
  }
}
