import 'package:kumoriya_testing/kumoriya_testing.dart';

void main() {
  final clock = FakeClock(DateTime(2026, 1, 1));
  clock.advance(const Duration(minutes: 30));
  print(clock.now());
}
