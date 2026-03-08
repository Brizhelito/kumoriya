import 'package:kumoriya_core/kumoriya_core.dart';

void main() {
  const result = Success<int, KumoriyaError>(42);
  final value = result.fold(onSuccess: (v) => v, onFailure: (_) => -1);
  print('core result value: $value');
}
