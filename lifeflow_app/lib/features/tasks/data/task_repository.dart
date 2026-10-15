import '../../../core/local/local_db.dart';
import '../domain/task.dart';

/// Tasks, stored on the device (synced by SyncService).
class TaskRepository {
  final LocalDb _db;
  static const _store = 'tasks';

  TaskRepository(this._db);

  /// By due date; tasks without one last.
  List<Task> fetchTasks() {
    final tasks = _db.all(_store).map(Task.fromJson).toList();
    tasks.sort((a, b) {
      if (a.dueDate == null || b.dueDate == null) {
        return a.dueDate == null ? (b.dueDate == null ? 0 : 1) : -1;
      }
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return tasks;
  }

  Future<Task> createTask(Task task) async {
    return Task.fromJson(await _db.save(_store, task.toJson()));
  }

  /// A recurring task marked done rolls its due date forward and goes back
  /// to "todo".
  Future<Task> updateTask(Task task) async {
    final data = task.toJson();
    final rule = _db.get(_store, task.id)?['recurrence_rule'] as String?;
    if (data['status'] == 'done' && rule != null) {
      final d = task.dueDate ?? DateTime.now();
      final next = switch (rule) {
        'daily' => DateTime(d.year, d.month, d.day + 1, d.hour, d.minute),
        'weekly' => DateTime(d.year, d.month, d.day + 7, d.hour, d.minute),
        _ => DateTime(d.year, d.month + 1, d.day, d.hour, d.minute),
      };
      data['due_date'] = next.toIso8601String();
      data['status'] = 'todo';
    }
    return Task.fromJson(await _db.save(_store, data, id: task.id));
  }

  Future<void> deleteTask(String id) => _db.delete(_store, id);
}
