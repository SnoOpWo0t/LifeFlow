import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/local/local_providers.dart';
import '../../data/bills_repository.dart';
import '../../domain/bill_models.dart';

final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  return BillsRepository(ref.watch(localDbProvider));
});

final billsListProvider =
    AsyncNotifierProvider<BillsListNotifier, List<Bill>>(
  BillsListNotifier.new,
);

class BillsListNotifier extends AsyncNotifier<List<Bill>> {
  @override
  List<Bill> build() {
    ref.watch(dataVersionProvider);
    return ref.watch(billsRepositoryProvider).fetchBills();
  }

  Future<void> addBill({
    required String title,
    required double amount,
    required DateTime dueDate,
    String frequency = 'monthly',
    String account = 'bank',
    String? note,
    String? categoryId,
  }) async {
    final repo = ref.read(billsRepositoryProvider);
    await repo.createBill({
      'title': title,
      'amount': amount,
      'due_date':
          "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}",
      'frequency': frequency,
      'account': account,
      'is_paid': false,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'category_id': ?categoryId,
    });
  }

  Future<void> updateBill(String id, Map<String, dynamic> data) async {
    final repo = ref.read(billsRepositoryProvider);
    await repo.updateBill(id, data);
  }

  Future<void> markAsPaid(String id, {bool recordExpense = true}) async {
    final repo = ref.read(billsRepositoryProvider);
    await repo.markAsPaid(id, recordExpense: recordExpense);
  }

  Future<void> deleteBill(String id) async {
    final repo = ref.read(billsRepositoryProvider);
    await repo.deleteBill(id);
  }
}

/// Filter: 'upcoming', 'paid', 'all'
final billsFilterProvider =
    NotifierProvider<BillsFilterNotifier, String>(BillsFilterNotifier.new);

class BillsFilterNotifier extends Notifier<String> {
  @override
  String build() => 'upcoming';

  void setFilter(String filter) => state = filter;
}

final filteredBillsProvider = Provider<List<Bill>>((ref) {
  final bills = ref.watch(billsListProvider).value ?? [];
  final filter = ref.watch(billsFilterProvider);

  return switch (filter) {
    'paid' => bills.where((b) => b.isPaid).toList(),
    'all' => bills,
    _ => bills.where((b) => !b.isPaid).toList(), // 'upcoming'
  };
});

class BillsSummary {
  final double totalUpcoming;
  final int upcomingCount;
  final int overdueCount;

  const BillsSummary({
    required this.totalUpcoming,
    required this.upcomingCount,
    required this.overdueCount,
  });
}

final billsSummaryProvider = Provider<BillsSummary>((ref) {
  final bills = ref.watch(billsListProvider).value ?? [];
  double total = 0.0;
  int upcoming = 0;
  int overdue = 0;

  for (final b in bills) {
    if (!b.isPaid) {
      total += b.amount;
      upcoming++;
      if (b.isOverdue) overdue++;
    }
  }

  return BillsSummary(
    totalUpcoming: total,
    upcomingCount: upcoming,
    overdueCount: overdue,
  );
});
