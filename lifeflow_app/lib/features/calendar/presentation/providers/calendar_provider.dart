import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/calendar_repository.dart';
import '../../domain/calendar_models.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(localDbProvider));
});

/// Per-day activity for a month. Key: the 1st of that month.
final calendarMonthProvider = FutureProvider.autoDispose
    .family<CalendarMonth, DateTime>((ref, month) {
      ref.watch(dataVersionProvider);
      return ref.watch(calendarRepositoryProvider).fetchMonth(month);
    });

/// Tasks, habit check-ins and transactions on one day.
final calendarDayProvider = FutureProvider.autoDispose
    .family<CalendarDayDetail, DateTime>((ref, day) {
      ref.watch(dataVersionProvider);
      return ref.watch(calendarRepositoryProvider).fetchDay(day);
    });
