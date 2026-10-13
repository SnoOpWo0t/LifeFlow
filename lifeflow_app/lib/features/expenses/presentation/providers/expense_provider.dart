import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense_models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});

/// Transactions, newest first, loaded 30 at a time. Call
/// `ref.read(transactionsProvider.notifier).loadMore()` near the end of the list.
final transactionsProvider =
    AsyncNotifierProvider.autoDispose<TransactionsNotifier, TransactionFeed>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends AsyncNotifier<TransactionFeed> {
  int _page = 1;

  @override
  Future<TransactionFeed> build() async {
    _page = 1;
    final first = await ref
        .watch(expenseRepositoryProvider)
        .fetchTransactions();
    return TransactionFeed(first.items, hasMore: first.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(expenseRepositoryProvider)
          .fetchTransactions(page: _page + 1);
      _page++;
      state = AsyncData(
        TransactionFeed([
          ...current.items,
          ...next.items,
        ], hasMore: next.hasMore),
      );
    } catch (_) {
      // Keep what we have; scrolling again retries.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

/// This month's spending per category, totalled on the server (the list above
/// is paginated, so the app no longer holds every transaction).
final spendingByCategoryProvider =
    FutureProvider.autoDispose<List<CategorySpending>>((ref) {
      return ref.watch(expenseRepositoryProvider).fetchSpendingByCategory();
    });

final chartDataProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(expenseRepositoryProvider).fetchChartData();
    });

final categoriesProvider = FutureProvider.autoDispose<List<ExpenseCategory>>((
  ref,
) {
  return ref.watch(expenseRepositoryProvider).fetchCategories();
});
