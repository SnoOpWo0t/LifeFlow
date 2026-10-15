import '../../../core/local/local_db.dart';
import '../../../core/utils/dates.dart';
import '../domain/habit_models.dart';

/// Habits and their daily check-ins, stored on the device (synced by
/// SyncService). A check-in's id is "<habit id>_<YYYY-MM-DD>", so the same day
/// checked on two devices is one record.
class HabitRepository {
  final LocalDb _db;
  static const _habits = 'habits';
  static const _logs = 'habit_logs';

  HabitRepository(this._db);

  /// Each habit with its streaks and the last 7 days' check-ins.
  List<Habit> fetchHabits() {
    final today = dayOf(DateTime.now());
    final weekStart = dateKey(today.subtract(const Duration(days: 6)));
    final logsByHabit = <String, List<Map<String, dynamic>>>{};
    for (final log in _db.all(_logs)) {
      logsByHabit.putIfAbsent(log['habit_id'] as String, () => []).add(log);
    }
    final habits = _db.all(_habits)
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));

    return [
      for (final h in habits)
        () {
          final logs = logsByHabit[h['id']] ?? const [];
          final days = {for (final l in logs) l['completed_date'] as String};
          final streaks = streaksFor(days, today);
          final recent =
              logs
                  .where(
                    (l) =>
                        (l['completed_date'] as String).compareTo(weekStart) >=
                        0,
                  )
                  .toList()
                ..sort(
                  (a, b) => (a['completed_date'] as String).compareTo(
                    b['completed_date'] as String,
                  ),
                );
          return Habit.fromJson({
            ...h,
            'current_streak': streaks.current,
            'longest_streak': streaks.longest,
            'logs': recent,
          });
        }(),
    ];
  }

  Future<Habit> createHabit(Habit habit) async {
    final record = await _db.save(_habits, habit.toJson());
    return Habit.fromJson({
      ...record,
      'current_streak': 0,
      'longest_streak': 0,
      'logs': const [],
    });
  }

  /// Checks today off, or unchecks it.
  Future<Habit> toggleHabit(String id) async {
    final today = dateKey(DateTime.now());
    final logId = '${id}_$today';
    if (_db.get(_logs, logId) != null) {
      await _db.delete(_logs, logId);
    } else {
      await _db.save(_logs, {
        'habit_id': id,
        'completed_date': today,
      }, id: logId);
    }
    return fetchHabits().firstWhere((h) => h.id == id);
  }

  Future<Habit> updateHabit(String id, Map<String, dynamic> data) async {
    await _db.save(_habits, data, id: id);
    return fetchHabits().firstWhere((h) => h.id == id);
  }

  Future<void> deleteHabit(String id) => _db.delete(_habits, id);
}

/// current: consecutive days ending today, or ending yesterday if today isn't
/// checked yet (the streak is alive until midnight). longest: best run ever.
({int current, int longest}) streaksFor(Set<String> days, DateTime today) {
  final sorted = days.toList()..sort();
  var longest = 0;
  var run = 0;
  DateTime? previous;
  for (final key in sorted) {
    final day = DateTime.parse(key);
    final continues =
        previous != null &&
        dateKey(DateTime(previous.year, previous.month, previous.day + 1)) ==
            key;
    run = continues ? run + 1 : 1;
    if (run > longest) longest = run;
    previous = day;
  }

  var cursor = dayOf(today);
  if (!days.contains(dateKey(cursor))) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var current = 0;
  while (days.contains(dateKey(cursor))) {
    current++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return (current: current, longest: longest);
}
