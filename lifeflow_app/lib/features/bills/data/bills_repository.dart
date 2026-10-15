import '../../../core/local/local_db.dart';
import '../domain/bill_models.dart';

class BillsRepository {
  final LocalDb _db;
  static const _store = 'bills';

  BillsRepository(this._db);

  List<Bill> fetchBills() {
    final rows = _db.all(_store)
      ..sort((a, b) {
        final paidA = a['is_paid'] == true || a['is_paid'] == 1 ? 1 : 0;
        final paidB = b['is_paid'] == true || b['is_paid'] == 1 ? 1 : 0;
        if (paidA != paidB) return paidA.compareTo(paidB);

        final dateA = '${a['due_date'] ?? '9999'}';
        final dateB = '${b['due_date'] ?? '9999'}';
        return dateA.compareTo(dateB);
      });

    return rows.map(Bill.fromJson).toList();
  }

  Future<Bill> createBill(Map<String, dynamic> data) async {
    final record = await _db.save(_store, data);
    return Bill.fromJson(record);
  }

  Future<Bill> updateBill(String id, Map<String, dynamic> data) async {
    final record = await _db.save(_store, data, id: id);
    return Bill.fromJson(record);
  }

  /// 1-tap "Mark as Paid":
  /// 1. Updates bill payment status (and advances due date if recurring).
  /// 2. Creates an expense transaction in the transactions store.
  Future<void> markAsPaid(String id, {bool recordExpense = true}) async {
    final existing = _db.get(_store, id);
    if (existing == null) return;

    final bill = Bill.fromJson(existing);
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (recordExpense) {
      await _db.save('transactions', {
        'amount': bill.amount,
        'type': 'expense',
        'account': bill.account,
        'transaction_date': todayStr,
        'note': 'Bill payment: ${bill.title}',
        if (bill.categoryId != null) 'category_id': bill.categoryId,
      });
    }

    if (!bill.isRecurring) {
      await _db.save(_store, {
        'is_paid': true,
        'last_paid_at': todayStr,
      }, id: id);
    } else {
      // Advance due date to the next cycle
      final currentDue = bill.dueDate;
      final nextDue = switch (bill.frequency) {
        'weekly' => currentDue.add(const Duration(days: 7)),
        'quarterly' => DateTime(
            currentDue.year,
            currentDue.month + 3,
            currentDue.day,
          ),
        'yearly' => DateTime(
            currentDue.year + 1,
            currentDue.month,
            currentDue.day,
          ),
        _ => DateTime(
            currentDue.year,
            currentDue.month + 1,
            currentDue.day,
          ), // monthly
      };

      final nextDueStr =
          "${nextDue.year.toString().padLeft(4, '0')}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}";

      await _db.save(_store, {
        'due_date': nextDueStr,
        'is_paid': false,
        'last_paid_at': todayStr,
      }, id: id);
    }
  }

  Future<void> deleteBill(String id) => _db.delete(_store, id);
}
