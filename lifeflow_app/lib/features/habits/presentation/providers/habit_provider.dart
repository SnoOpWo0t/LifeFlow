import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit_models.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(apiClientProvider));
});

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<Habit>>(HabitsNotifier.new);

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() async {
    return ref.watch(habitRepositoryProvider).fetchHabits();
  }

  Future<void> addHabit(Habit habit) async {
    final repo = ref.read(habitRepositoryProvider);
    final current = state.value ?? [];
    final newHabit = await repo.createHabit(habit);
    state = AsyncData([...current, newHabit]);
  }

  Future<void> toggleHabit(int id) async {
    final repo = ref.read(habitRepositoryProvider);
    final current = state.value ?? [];
    try {
      final updatedHabit = await repo.toggleHabit(id);
      state = AsyncData(current.map((h) => h.id == id ? updatedHabit : h).toList());
    } catch (e) {
      // Handle error
    }
  }
}
