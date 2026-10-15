import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/habit_repository.dart';
import '../../domain/habit_models.dart';

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(localDbProvider));
});

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<Habit>>(
  HabitsNotifier.new,
);

class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  @override
  List<Habit> build() {
    ref.watch(dataVersionProvider);
    return ref.watch(habitRepositoryProvider).fetchHabits();
  }

  Future<void> addHabit(Habit habit) async {
    await ref.read(habitRepositoryProvider).createHabit(habit);
  }

  Future<void> toggleHabit(String id) async {
    await ref.read(habitRepositoryProvider).toggleHabit(id);
  }

  Future<void> renameHabit(String id, String name) async {
    await ref.read(habitRepositoryProvider).updateHabit(id, {'name': name});
  }

  Future<void> deleteHabit(String id) async {
    await ref.read(habitRepositoryProvider).deleteHabit(id);
  }
}
