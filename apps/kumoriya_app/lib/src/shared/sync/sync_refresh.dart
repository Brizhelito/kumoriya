import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncDataRefreshEpochProvider =
    NotifierProvider<SyncDataRefreshEpochNotifier, int>(
      SyncDataRefreshEpochNotifier.new,
    );

class SyncDataRefreshEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state++;
  }
}
