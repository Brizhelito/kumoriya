import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:test/test.dart';

void main() {
  test('result fold routes values', () {
    const success = Success<int, KumoriyaError>(7);
    const failure = Failure<int, KumoriyaError>(
      SimpleError(code: 'x', message: 'y'),
    );

    expect(success.fold(onSuccess: (v) => v, onFailure: (_) => 0), 7);
    expect(
      failure.fold(onSuccess: (v) => v, onFailure: (e) => e.code.length),
      1,
    );
  });
}
