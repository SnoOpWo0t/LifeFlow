import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/savings_repository.dart';
import '../../domain/savings_models.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository(ref.watch(localDbProvider));
});

final savingsListProvider =
    AsyncNotifierProvider<SavingsListNotifier, List<Saving>>(
  SavingsListNotifier.new,
);

class SavingsListNotifier extends AsyncNotifier<List<Saving>> {
  @override
  List<Saving> build() {
    ref.watch(dataVersionProvider);
    return ref.watch(savingsRepositoryProvider).fetchSavings();
  }

  Future<void> addSaving({
    required double amount,
    required String type,
    required String account,
    required DateTime transactionDate,
    String? note,
  }) async {
    final repo = ref.read(savingsRepositoryProvider);
    await repo.createSaving({
      'amount': amount,
      'type': type,
      'account': account,
      'transaction_date':
          "${transactionDate.year.toString().padLeft(4, '0')}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> updateSaving(String id, Map<String, dynamic> data) async {
    final repo = ref.read(savingsRepositoryProvider);
    await repo.updateSaving(id, data);
  }

  Future<void> deleteSaving(String id) async {
    final repo = ref.read(savingsRepositoryProvider);
    await repo.deleteSaving(id);
  }
}

final savingsSummaryProvider = Provider<SavingsSummary>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(savingsRepositoryProvider).computeSummary();
});

/// Account filter: 'all', 'bank', 'bkash', 'nagad', 'cash'
final savingsAccountFilterProvider =
    NotifierProvider<SavingsAccountFilterNotifier, String>(
  SavingsAccountFilterNotifier.new,
);

class SavingsAccountFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) => state = filter;
}

/// Type filter: 'all', 'deposit', 'withdrawal'
final savingsTypeFilterProvider =
    NotifierProvider<SavingsTypeFilterNotifier, String>(
  SavingsTypeFilterNotifier.new,
);

class SavingsTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) => state = filter;
}

/// Filtered list of savings
final filteredSavingsProvider = Provider<List<Saving>>((ref) {
  final savingsAsync = ref.watch(savingsListProvider);
  final allSavings = savingsAsync.value ?? [];
  final accountFilter = ref.watch(savingsAccountFilterProvider);
  final typeFilter = ref.watch(savingsTypeFilterProvider);

  return allSavings.where((item) {
    if (accountFilter != 'all' &&
        item.account.toLowerCase() != accountFilter.toLowerCase()) {
      return false;
    }
    if (typeFilter != 'all' &&
        item.type.toLowerCase() != typeFilter.toLowerCase()) {
      return false;
    }
    return true;
  }).toList();
});
