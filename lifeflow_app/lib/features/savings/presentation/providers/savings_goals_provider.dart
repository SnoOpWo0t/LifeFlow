import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/savings_goals_repository.dart';
import '../../domain/savings_goal_models.dart';

final savingsGoalsRepositoryProvider = Provider<SavingsGoalsRepository>((ref) {
  return SavingsGoalsRepository(ref.watch(localDbProvider));
});

final savingsGoalsListProvider =
    AsyncNotifierProvider<SavingsGoalsListNotifier, List<SavingsGoal>>(
  SavingsGoalsListNotifier.new,
);

class SavingsGoalsListNotifier extends AsyncNotifier<List<SavingsGoal>> {
  @override
  List<SavingsGoal> build() {
    ref.watch(dataVersionProvider);
    return ref.watch(savingsGoalsRepositoryProvider).fetchGoals();
  }

  Future<void> addGoal({
    required String title,
    required double targetAmount,
    double savedAmount = 0.0,
    DateTime? targetDate,
    String? category,
    String? colorHex,
  }) async {
    final repo = ref.read(savingsGoalsRepositoryProvider);
    await repo.createGoal({
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      if (targetDate != null)
        'target_date':
            "${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}",
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      'color_hex': ?colorHex,
      'is_completed': savedAmount >= targetAmount && targetAmount > 0,
    });
  }

  Future<void> updateGoal(String id, Map<String, dynamic> data) async {
    final repo = ref.read(savingsGoalsRepositoryProvider);
    await repo.updateGoal(id, data);
  }

  Future<void> contribute(String id, double amount) async {
    final repo = ref.read(savingsGoalsRepositoryProvider);
    await repo.contribute(id, amount);
  }

  Future<void> deleteGoal(String id) async {
    final repo = ref.read(savingsGoalsRepositoryProvider);
    await repo.deleteGoal(id);
  }
}

final savingsGoalsVisibleProvider =
    NotifierProvider<SavingsGoalsVisibleNotifier, bool>(
  SavingsGoalsVisibleNotifier.new,
);

class SavingsGoalsVisibleNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(settingsRepositoryProvider).savingsGoalsVisible;
  }

  Future<void> toggle() async {
    final newState = !state;
    state = newState;
    await ref.read(settingsRepositoryProvider).setSavingsGoalsVisible(newState);
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    await ref.read(settingsRepositoryProvider).setSavingsGoalsVisible(visible);
  }
}

final activeSavingsGoalsProvider = Provider<List<SavingsGoal>>((ref) {
  final goalsAsync = ref.watch(savingsGoalsListProvider);
  final all = goalsAsync.value ?? [];
  return all.where((g) => !g.isCompleted).toList();
});
