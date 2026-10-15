import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
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
