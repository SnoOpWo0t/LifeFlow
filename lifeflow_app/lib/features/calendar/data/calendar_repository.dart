import '../../../core/local/local_db.dart';
import '../../expenses/domain/expense_models.dart';
import '../../tasks/domain/task.dart';
import '../domain/calendar_models.dart';

/// The dashboard calendar, worked out from the data on the device.
class CalendarRepository {
  final LocalDb _db;

  CalendarRepository(this._db);

  static String? _dueKey(Map<String, dynamic> t) {
    final due = DateTime.tryParse('${t['due_date']}');
    return due == null ? null : dateKey(due.isUtc ? due.toLocal() : due);
  }

  Set<String> get _habitIds => {
    for (final h in _db.all('habits')) h['id'] as String,
  };

  /// Per-day activity for [month]: only days with something on them.
  CalendarMonth fetchMonth(DateTime month) {
    final prefix = dateKey(month).substring(0, 7);
    final days =
        <
          String,
          ({int due, int done, int habits, double spent, double earned})
        >{};
    void add(
      String date, {
      int due = 0,
      int done = 0,
      int habits = 0,
      double spent = 0,
      double earned = 0,
    }) {
      final d =
          days[date] ?? (due: 0, done: 0, habits: 0, spent: 0.0, earned: 0.0);
      days[date] = (
        due: d.due + due,
        done: d.done + done,
        habits: d.habits + habits,
        spent: d.spent + spent,
        earned: d.earned + earned,
      );
    }

    for (final t in _db.all('tasks')) {
      final due = _dueKey(t);
      if (due == null || !due.startsWith(prefix)) continue;
      add(due, due: 1, done: t['status'] == 'done' ? 1 : 0);
    }
    final habitIds = _habitIds;
    for (final l in _db.all('habit_logs')) {
      final date = l['completed_date'] as String;
      if (habitIds.contains(l['habit_id']) && date.startsWith(prefix)) {
        add(date, habits: 1);
      }
    }
    for (final tx in _db.all('transactions')) {
      final date = tx['transaction_date'] as String;
      if (!date.startsWith(prefix)) continue;
      final amount = double.parse(tx['amount'].toString());
      tx['type'] == 'income'
          ? add(date, earned: amount)
          : add(date, spent: amount);
    }

    return CalendarMonth(
      habitsTotal: habitIds.length,
      days: {
        for (final e in days.entries)
          e.key: CalendarDaySummary(
            tasksDue: e.value.due,
            tasksDone: e.value.done,
            habitsDone: e.value.habits,
            spent: e.value.spent,
            earned: e.value.earned,
          ),
      },
    );
  }

  /// Everything on one day: tasks due, each habit's check-in, transactions.
  CalendarDayDetail fetchDay(DateTime day) {
    final key = dateKey(day);
    final tasks = _db.all('tasks').where((t) => _dueKey(t) == key).toList()
      ..sort((a, b) => '${a['status']}'.compareTo('${b['status']}'));
    final checked = {
      for (final l in _db.all('habit_logs'))
        if (l['completed_date'] == key) l['habit_id'],
    };
    final habits = _db.all('habits')
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    final transactions =
        _db
            .all('transactions')
            .where((t) => t['transaction_date'] == key)
            .toList()
          ..sort(
            (a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'),
          );

    return CalendarDayDetail(
      tasks: tasks.map(Task.fromJson).toList(),
      habits: [
        for (final h in habits)
          HabitCheck(
            name: h['name'] as String,
            colorHex: h['color_hex'] as String?,
            done: checked.contains(h['id']),
          ),
      ],
      transactions: [
        for (final t in transactions)
          Transaction.fromJson({
            ...t,
            'category': _db.get('categories', t['category_id'] as String?),
          }),
      ],
    );
  }
}
