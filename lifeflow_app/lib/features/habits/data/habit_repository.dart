import '../../../core/network/api_client.dart';
import '../domain/habit_models.dart';

class HabitRepository {
  final ApiClient _apiClient;

  HabitRepository(this._apiClient);

  Future<List<Habit>> fetchHabits() async {
    final response = await _apiClient.dio.get('/habits');
    return (response.data as List).map((json) => Habit.fromJson(json)).toList();
  }

  Future<Habit> createHabit(Habit habit) async {
    final response = await _apiClient.dio.post('/habits', data: habit.toJson());
    return Habit.fromJson(response.data);
  }

  Future<Habit> toggleHabit(int id) async {
    final response = await _apiClient.dio.post('/habits/$id/toggle');
    return Habit.fromJson(response.data);
  }

  Future<void> deleteHabit(int id) async {
    await _apiClient.dio.delete('/habits/$id');
  }
}
