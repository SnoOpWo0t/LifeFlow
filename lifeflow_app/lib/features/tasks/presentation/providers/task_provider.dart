import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/task_repository.dart';
import '../../domain/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() async {
    return ref.watch(taskRepositoryProvider).fetchTasks();
  }

  Future<void> addTask(Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    final current = state.value ?? [];

    // Add optimistic logic if desired, or just wait for server
    final newTask = await repo.createTask(task);
    state = AsyncData([...current, newTask]);
  }

  Future<void> updateTaskStatus(Task task, String newStatus) async {
    final repo = ref.read(taskRepositoryProvider);
    final current = state.value ?? [];

    final updatedTask = task.copyWith(status: newStatus);
    state = AsyncData(
      current.map((t) => t.id == task.id ? updatedTask : t).toList(),
    );

    try {
      final serverTask = await repo.updateTask(updatedTask);
      state = AsyncData(
        state.value!.map((t) => t.id == task.id ? serverTask : t).toList(),
      );
    } catch (e) {
      state = AsyncData(current); // revert
    }
  }

  Future<void> deleteTask(Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    final current = state.value ?? [];

    // Optimistic delete
    state = AsyncData(current.where((t) => t.id != task.id).toList());

    try {
      await repo.deleteTask(task.id);
    } catch (e) {
      state = AsyncData(current); // revert on error
    }
  }
}
