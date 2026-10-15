import '../../../core/local/local_db.dart';
import '../../../core/utils/dates.dart';
import '../domain/analytics_models.dart';

/// The last 7 days, worked out from the data on the device.
class AnalyticsRepository {
  final LocalDb _db;

  AnalyticsRepository(this._db);

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  WeeklyAnalytics fetchWeeklyStats({DateTime? now}) {
    now ??= DateTime.now();
    final keys = [
      for (var i = 6; i >= 0; i--)
        dateKey(DateTime(now.year, now.month, now.day - i)),
    ];
    final tasks = {for (final k in keys) k: 0};
    final habits = {for (final k in keys) k: 0};
    final expenses = {for (final k in keys) k: 0.0};
    final income = {for (final k in keys) k: 0.0};

    for (final t in _db.all('tasks')) {
      if (t['status'] != 'done') continue;
      final done = DateTime.tryParse('${t['updated_at']}');
      final key = done == null ? null : dateKey(done.toLocal());
      if (tasks.containsKey(key)) tasks[key!] = tasks[key]! + 1;
    }
    final habitIds = {for (final h in _db.all('habits')) h['id']};
    for (final l in _db.all('habit_logs')) {
      final key = l['completed_date'] as String;
      if (habitIds.contains(l['habit_id']) && habits.containsKey(key)) {
        habits[key] = habits[key]! + 1;
      }
    }
    var savings = 0.0;
    for (final tx in _db.all('transactions')) {
      final key = tx['transaction_date'] as String;
      if (!income.containsKey(key)) continue;
      final amount = double.parse(tx['amount'].toString());
      if (tx['type'] == 'expense') {
        expenses[key] = expenses[key]! + amount;
        savings -= amount;
      } else {
        income[key] = income[key]! + amount;
        savings += amount;
      }
    }

    final days = [
      for (final k in keys)
        DailyStats(
          dayName: _dayNames[DateTime.parse(k).weekday - 1],
          tasksCompleted: tasks[k]!,
          habitsCompleted: habits[k]!,
          expenses: expenses[k]!,
          income: income[k]!,
          productivityScore: tasks[k]! + habits[k]!,
        ),
    ];
    var best = days.first;
    for (final d in days) {
      if (d.productivityScore > best.productivityScore) best = d;
    }

    return WeeklyAnalytics(
      weeklyData: days,
      totalSavings: savings,
      mostProductiveDay: best.productivityScore == 0 ? 'None' : best.dayName,
      maxProductivityScore: best.productivityScore,
    );
  }
}
