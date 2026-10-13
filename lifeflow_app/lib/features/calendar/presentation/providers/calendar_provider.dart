import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/calendar_repository.dart';
import '../../domain/calendar_models.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(apiClientProvider));
});

/// Per-day activity for a month. Key: the 1st of that month.
final calendarMonthProvider = FutureProvider.autoDispose
    .family<CalendarMonth, DateTime>((ref, month) {
      return ref.watch(calendarRepositoryProvider).fetchMonth(month);
    });

/// Tasks, habit check-ins and transactions on one day.
final calendarDayProvider = FutureProvider.autoDispose
    .family<CalendarDayDetail, DateTime>((ref, day) {
      return ref.watch(calendarRepositoryProvider).fetchDay(day);
    });
