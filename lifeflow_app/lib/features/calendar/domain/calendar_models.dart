import '../../expenses/domain/expense_models.dart';
import '../../tasks/domain/task.dart';

/// "2026-10-14": the key the API uses for a day.
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The 42 days (6 weeks, Monday first) shown for [month], including the
/// trailing days of the previous month and leading days of the next.
List<DateTime> monthGrid(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final start = first.subtract(Duration(days: first.weekday - DateTime.monday));
  // Calendar arithmetic (not Duration) so daylight-saving shifts can't skip a day.
  return List.generate(
    42,
    (i) => DateTime(start.year, start.month, start.day + i),
  );
}

/// One day's activity from `GET /calendar`.
class CalendarDaySummary {
  final int tasksDue;
  final int tasksDone;
  final int habitsDone;
  final double spent;
  final double earned;

  const CalendarDaySummary({
    required this.tasksDue,
    required this.tasksDone,
    required this.habitsDone,
    required this.spent,
    required this.earned,
  });

  factory CalendarDaySummary.fromJson(Map<String, dynamic> json) =>
      CalendarDaySummary(
        tasksDue: (json['tasks_due'] as num).toInt(),
        tasksDone: (json['tasks_done'] as num).toInt(),
        habitsDone: (json['habits_done'] as num).toInt(),
        spent: double.parse(json['spent'].toString()),
        earned: double.parse(json['earned'].toString()),
      );
}

class CalendarMonth {
  final int habitsTotal;

  /// Only days with activity, keyed by [dateKey].
  final Map<String, CalendarDaySummary> days;

  const CalendarMonth({required this.habitsTotal, required this.days});

  factory CalendarMonth.fromJson(Map<String, dynamic> json) => CalendarMonth(
    habitsTotal: (json['habits_total'] as num).toInt(),
    days: {
      for (final day in json['days'] as List)
        day['date'] as String: CalendarDaySummary.fromJson(day),
    },
  );
}

class HabitCheck {
  final String name;
  final String? colorHex;
  final bool done;

  const HabitCheck({required this.name, this.colorHex, required this.done});

  factory HabitCheck.fromJson(Map<String, dynamic> json) => HabitCheck(
    name: json['name'] as String,
    colorHex: json['color_hex'] as String?,
    done: json['done'] == true,
  );
}

/// Everything on one day from `GET /calendar/day`.
class CalendarDayDetail {
  final List<Task> tasks;
  final List<HabitCheck> habits;
  final List<Transaction> transactions;

  const CalendarDayDetail({
    required this.tasks,
    required this.habits,
    required this.transactions,
  });

  bool get isEmpty =>
      tasks.isEmpty && transactions.isEmpty && habits.every((h) => !h.done);

  factory CalendarDayDetail.fromJson(Map<String, dynamic> json) =>
      CalendarDayDetail(
        tasks: (json['tasks'] as List).map((j) => Task.fromJson(j)).toList(),
        habits: (json['habits'] as List)
            .map((j) => HabitCheck.fromJson(j))
            .toList(),
        transactions: (json['transactions'] as List)
            .map((j) => Transaction.fromJson(j))
            .toList(),
      );
}
