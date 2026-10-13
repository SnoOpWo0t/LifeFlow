import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense_models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((
  ref,
) {
  return ref.watch(expenseRepositoryProvider).fetchTransactions();
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
