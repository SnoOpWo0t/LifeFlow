import '../../../core/network/api_client.dart';
import '../domain/task.dart';

class TaskRepository {
  final ApiClient _apiClient;

  TaskRepository(this._apiClient);

  Future<List<Task>> fetchTasks() async {
    final response = await _apiClient.dio.get('/tasks');
    return (response.data as List).map((json) => Task.fromJson(json)).toList();
  }

  Future<Task> createTask(Task task) async {
    final response = await _apiClient.dio.post('/tasks', data: task.toJson());
    return Task.fromJson(response.data);
  }

  Future<Task> updateTask(Task task) async {
    final response = await _apiClient.dio.put(
      '/tasks/${task.id}',
      data: task.toJson(),
    );
    return Task.fromJson(response.data);
  }

  Future<void> deleteTask(int id) async {
    await _apiClient.dio.delete('/tasks/$id');
  }
}
