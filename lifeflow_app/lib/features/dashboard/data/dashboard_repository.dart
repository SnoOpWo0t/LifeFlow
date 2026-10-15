import '../../../core/local/local_db.dart';
import '../../../core/utils/dates.dart';
import '../domain/dashboard_summary.dart';

/// The dashboard's numbers, worked out from the data on the device.
class DashboardRepository {
  final LocalDb _db;

  /// The monthly budget from Settings.
  final double Function() _budget;

  DashboardRepository(this._db, this._budget);

  DashboardSummary fetchSummary({DateTime? now}) {
    now ??= DateTime.now();
    final today = dateKey(now);
    final monthStart = dateKey(DateTime(now.year, now.month, 1));

    // Today's tasks: due today, overdue and still open, or finished today.
    final tasks = _db.all('tasks');
    final tasksToday = tasks.where((t) {
      final due = _dueKey(t);
      final done = t['status'] == 'done';
      return due == today ||
          (due != null && due.compareTo(today) < 0 && !done) ||
          (done && _localKey(t['updated_at']) == today);
    }).toList();
    final tasksCompleted = tasksToday
        .where((t) => t['status'] == 'done')
        .length;

    final habitIds = {for (final h in _db.all('habits')) h['id']};
    final habitsCompleted = _db
        .all('habit_logs')
        .where(
          (l) =>
              habitIds.contains(l['habit_id']) && l['completed_date'] == today,
        )
        .length;

    final transactions = _db.all('transactions');
    double sum(Iterable<Map<String, dynamic>> rows) =>
        rows.fold(0.0, (s, r) => s + double.parse(r['amount'].toString()));
    final thisMonth = transactions.where(
      (t) => (t['transaction_date'] as String).compareTo(monthStart) >= 0,
    );

    final taskScore = tasksToday.isEmpty
        ? 0.0
        : tasksCompleted / tasksToday.length;
    final habitScore = habitIds.isEmpty
        ? 0.0
        : habitsCompleted / habitIds.length;
    final parts = (tasksToday.isEmpty ? 0 : 1) + (habitIds.isEmpty ? 0 : 1);
    final score = parts == 0 ? 0 : ((taskScore + habitScore) / parts * 100);

    return DashboardSummary(
      tasksCompleted: tasksCompleted,
      tasksTotal: tasksToday.length,
      habitsCompleted: habitsCompleted,
      habitsTotal: habitIds.length,
      monthlyExpenses: sum(thisMonth.where((t) => t['type'] == 'expense')),
      monthlyIncome: sum(thisMonth.where((t) => t['type'] == 'income')),
      monthlyBudget: _budget(),
      productivityScore: score.round(),
      recentActivity: _recent(transactions, tasks),
      accountBalances: {
        for (final account in const ['cash', 'bkash', 'nagad', 'bank'])
          account:
              sum(
                transactions.where(
                  (t) =>
                      (t['account'] ?? 'cash') == account &&
                      t['type'] == 'income',
                ),
              ) -
              sum(
                transactions.where(
                  (t) =>
                      (t['account'] ?? 'cash') == account &&
                      t['type'] == 'expense',
                ),
              ),
      },
    );
  }

  /// The latest 3 transactions and 3 finished tasks, newest 5 of those.
  List<RecentActivity> _recent(
    List<Map<String, dynamic>> transactions,
    List<Map<String, dynamic>> tasks,
  ) {
    final txs = [...transactions]
      ..sort((a, b) {
        final byDate = (b['transaction_date'] as String).compareTo(
          a['transaction_date'] as String,
        );
        return byDate != 0
            ? byDate
            : '${b['created_at']}'.compareTo('${a['created_at']}');
      });
    final done = tasks.where((t) => t['status'] == 'done').toList()
      ..sort((a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'));

    final items = [
      for (final t in txs.take(3))
        RecentActivity(
          id: 'tx_${t['id']}',
          type: 'transaction',
          title: _txTitle(t),
          subtitle: t['type'] == 'income' ? 'Income' : 'Expense',
          amount: double.parse(t['amount'].toString()),
          isIncome: t['type'] == 'income',
          date: _txWhen(t),
        ),
      for (final t in done.take(3))
        RecentActivity(
          id: 'task_${t['id']}',
          type: 'task',
          title: t['title'] as String,
          subtitle: 'Completed Task',
          date: DateTime.parse(t['updated_at'] as String).toLocal(),
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return items.take(5).toList();
  }

  String _txTitle(Map<String, dynamic> t) {
    final note = t['note'] as String?;
    if (note != null && note.isNotEmpty) return note;
    return _db.get('categories', t['category_id'] as String?)?['name']
            as String? ??
        'Transaction';
  }

  /// When the money moved. Same-day entries keep their entry time, so they
  /// sort among today's tasks; older dates count as the end of that day.
  DateTime _txWhen(Map<String, dynamic> t) {
    final date = DateTime.parse(t['transaction_date'] as String);
    final created = DateTime.tryParse('${t['created_at']}')?.toLocal();
    if (created != null && dateKey(created) == dateKey(date)) return created;
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static String? _dueKey(Map<String, dynamic> t) {
    final due = DateTime.tryParse('${t['due_date']}');
    return due == null ? null : dateKey(due.isUtc ? due.toLocal() : due);
  }

  static String? _localKey(Object? utc) {
    final t = DateTime.tryParse('$utc');
    return t == null ? null : dateKey(t.toLocal());
  }
}
