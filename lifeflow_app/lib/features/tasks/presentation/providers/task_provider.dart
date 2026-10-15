import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/task_repository.dart';
import '../../domain/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(localDbProvider));
});

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

/// Read from the device, so it's instant and works offline. Rebuilds after
/// any change (including ones a sync brings in).
class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  List<Task> build() {
    ref.watch(dataVersionProvider);
    return ref.watch(taskRepositoryProvider).fetchTasks();
  }

  Future<void> addTask(Task task) async {
    await ref.read(taskRepositoryProvider).createTask(task);
  }

  Future<void> updateTaskStatus(Task task, String newStatus) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTask(task.copyWith(status: newStatus));
  }

  Future<void> deleteTask(Task task) async {
    await ref.read(taskRepositoryProvider).deleteTask(task.id);
  }
}
