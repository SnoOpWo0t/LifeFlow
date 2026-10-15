import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_db.dart';

/// Opened in main() before the app starts (tests use an in-memory one).
final localDbProvider = Provider<LocalDb>(
  (ref) => throw UnimplementedError('Override localDbProvider in main()'),
);

/// Goes up by one after every change to the local data, from this device or
/// a sync. Screens built from the data watch it to stay current.
final dataVersionProvider = NotifierProvider<DataVersionNotifier, int>(
  DataVersionNotifier.new,
);

class DataVersionNotifier extends Notifier<int> {
  @override
  int build() {
    final sub = ref.watch(localDbProvider).changes.listen((_) => state++);
    ref.onDispose(sub.cancel);
    return 0;
  }
}
