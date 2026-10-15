import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense_models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(localDbProvider));
});

/// All transactions, newest first. They're on the device, so there's no
/// paging; the list builds rows lazily as it scrolls.
final transactionsProvider =
    AsyncNotifierProvider.autoDispose<TransactionsNotifier, TransactionFeed>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends AsyncNotifier<TransactionFeed> {
  @override
  TransactionFeed build() {
    ref.watch(dataVersionProvider);
    return TransactionFeed(
      ref.watch(expenseRepositoryProvider).allTransactions(),
      hasMore: false,
    );
  }

  /// Kept for the list's scroll hook; everything is already loaded.
  Future<void> loadMore() async {}
}

/// This month's spending per category.
final spendingByCategoryProvider =
    FutureProvider.autoDispose<List<CategorySpending>>((ref) {
      ref.watch(dataVersionProvider);
      return ref.watch(expenseRepositoryProvider).fetchSpendingByCategory();
    });

final chartDataProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(dataVersionProvider);
      return ref.watch(expenseRepositoryProvider).fetchChartData();
    });

final categoriesProvider = FutureProvider.autoDispose<List<ExpenseCategory>>((
  ref,
) {
  ref.watch(dataVersionProvider);
  return ref.watch(expenseRepositoryProvider).fetchCategories();
});

/// Search query for transactions.
final transactionSearchQueryProvider =
    NotifierProvider<TransactionSearchQueryNotifier, String>(
  TransactionSearchQueryNotifier.new,
);

class TransactionSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

/// Type filter: 'all', 'income', 'expense'
final transactionTypeFilterProvider =
    NotifierProvider<TransactionTypeFilterNotifier, String>(
  TransactionTypeFilterNotifier.new,
);

class TransactionTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) => state = filter;
}

/// Wallet filter: 'all', 'cash', 'bkash', 'nagad', 'bank'
final transactionWalletFilterProvider =
    NotifierProvider<TransactionWalletFilterNotifier, String>(
  TransactionWalletFilterNotifier.new,
);

class TransactionWalletFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFilter(String filter) => state = filter;
}

/// Filtered list of transactions based on search query, type, and wallet.
final filteredTransactionsProvider =
    Provider.autoDispose<List<Transaction>>((ref) {
  final feed = ref.watch(transactionsProvider).value;
  if (feed == null) return [];

  final query = ref.watch(transactionSearchQueryProvider).trim().toLowerCase();
  final typeFilter = ref.watch(transactionTypeFilterProvider);
  final walletFilter = ref.watch(transactionWalletFilterProvider);

  return feed.items.where((tx) {
    // Type filter
    if (typeFilter != 'all' && tx.type != typeFilter) {
      return false;
    }

    // Wallet filter
    if (walletFilter != 'all' &&
        tx.account.toLowerCase() != walletFilter.toLowerCase()) {
      return false;
    }

    // Search query filter
    if (query.isNotEmpty) {
      final noteMatch = tx.note?.toLowerCase().contains(query) ?? false;
      final categoryMatch =
          tx.category?.name.toLowerCase().contains(query) ?? false;
      final amountMatch = tx.amount.toString().contains(query);
      final accountMatch = tx.account.toLowerCase().contains(query);

      if (!noteMatch && !categoryMatch && !amountMatch && !accountMatch) {
        return false;
      }
    }

    return true;
  }).toList();
});

/// Category budgets state and actions
final categoryBudgetsProvider =
    NotifierProvider<CategoryBudgetsNotifier, Map<String, double>>(
  CategoryBudgetsNotifier.new,
);

class CategoryBudgetsNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    return ref.watch(settingsRepositoryProvider).categoryBudgets;
  }

  Future<void> setBudget(String categoryKey, double amount) async {
    final updated = Map<String, double>.from(state);
    if (amount <= 0) {
      updated.remove(categoryKey);
    } else {
      updated[categoryKey] = amount;
    }
    state = updated;
    await ref.read(settingsRepositoryProvider).saveCategoryBudgets(updated);
  }

  Future<void> removeBudget(String categoryKey) async {
    final updated = Map<String, double>.from(state)..remove(categoryKey);
    state = updated;
    await ref.read(settingsRepositoryProvider).saveCategoryBudgets(updated);
  }
}

