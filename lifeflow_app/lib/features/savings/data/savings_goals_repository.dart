import '../../../core/local/local_db.dart';
import '../domain/savings_goal_models.dart';

class SavingsGoalsRepository {
  final LocalDb _db;
  static const _store = 'savings_goals';

  SavingsGoalsRepository(this._db);

  List<SavingsGoal> fetchGoals() {
    final rows = _db.all(_store)
      ..sort((a, b) {
        final compA = a['is_completed'] == true || a['is_completed'] == 1 ? 1 : 0;
        final compB = b['is_completed'] == true || b['is_completed'] == 1 ? 1 : 0;
        if (compA != compB) return compA.compareTo(compB);

        final dateA = '${a['target_date'] ?? '9999'}';
        final dateB = '${b['target_date'] ?? '9999'}';
        final dateCmp = dateA.compareTo(dateB);
        if (dateCmp != 0) return dateCmp;

        return '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}');
      });

    return rows.map(SavingsGoal.fromJson).toList();
  }

  Future<SavingsGoal> createGoal(Map<String, dynamic> data) async {
    final record = await _db.save(_store, data);
    return SavingsGoal.fromJson(record);
  }

  Future<SavingsGoal> updateGoal(String id, Map<String, dynamic> data) async {
    final record = await _db.save(_store, data, id: id);
    return SavingsGoal.fromJson(record);
  }

  Future<void> contribute(String id, double amount) async {
    final existing = _db.get(_store, id);
    if (existing == null) return;

    final currentSaved = double.tryParse(existing['saved_amount'].toString()) ?? 0.0;
    final target = double.tryParse(existing['target_amount'].toString()) ?? 0.0;
    final newSaved = (currentSaved + amount).clamp(0.0, double.infinity);
    final isCompleted = newSaved >= target && target > 0;

    final updated = Map<String, dynamic>.from(existing)
      ..['saved_amount'] = newSaved
      ..['is_completed'] = isCompleted;

    await _db.save(_store, updated, id: id);
  }

  Future<void> deleteGoal(String id) => _db.delete(_store, id);
}
