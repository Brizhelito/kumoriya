import 'package:kumoriya_testing/kumoriya_testing.dart';
import 'package:test/test.dart';

void main() {
  test('fake clock advances time', () {
    final clock = FakeClock(DateTime(2026, 1, 1));
    clock.advance(const Duration(hours: 2));
    expect(clock.now().hour, 2);
  });
}
