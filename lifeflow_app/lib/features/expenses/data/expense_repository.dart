import '../../../core/local/local_db.dart';
import '../../../core/utils/dates.dart';
import '../domain/expense_models.dart';

/// Transactions and categories, stored on the device (synced by SyncService).
/// Transactions keep a `category_id`; the category is looked up when read, so
/// renaming one shows everywhere.
class ExpenseRepository {
  final LocalDb _db;
  static const _tx = 'transactions';
  static const _cats = 'categories';
  static const pageSize = 30;

  ExpenseRepository(this._db);

  /// A transaction record with its category attached (null if deleted).
  Map<String, dynamic> _withCategory(Map<String, dynamic> r) => {
    ...r,
    'category': _db.get(_cats, r['category_id'] as String?),
  };

  /// Newest first: by date, then by when it was entered.
  List<Map<String, dynamic>> _sorted() {
    final rows = _db.all(_tx);
    rows.sort((a, b) {
      final byDate = (b['transaction_date'] as String).compareTo(
        a['transaction_date'] as String,
      );
      return byDate != 0
          ? byDate
          : '${b['created_at']}'.compareTo('${a['created_at']}');
    });
    return rows;
  }

  /// Newest first, [pageSize] at a time.
  TransactionPage fetchTransactions({int page = 1}) {
    final rows = _sorted();
    final start = (page - 1) * pageSize;
    final items = rows
        .skip(start)
        .take(pageSize)
        .map((r) => Transaction.fromJson(_withCategory(r)))
        .toList();
    return TransactionPage(items, hasMore: rows.length > start + pageSize);
  }

  /// Every transaction, newest first.
  List<Transaction> allTransactions() =>
      _sorted().map((r) => Transaction.fromJson(_withCategory(r))).toList();

  /// This month's spending per category, biggest first.
  List<CategorySpending> fetchSpendingByCategory() {
    final now = DateTime.now();
    final from = dateKey(DateTime(now.year, now.month, 1));
    final until = dateKey(DateTime(now.year, now.month + 1, 1));
    final totals = <String?, double>{};
    for (final r in _db.all(_tx)) {
      final date = r['transaction_date'] as String;
      if (r['type'] != 'expense' ||
          date.compareTo(from) < 0 ||
          date.compareTo(until) >= 0) {
        continue;
      }
      final category = _db.get(_cats, r['category_id'] as String?);
      final key = category?['id'] as String?;
      totals[key] = (totals[key] ?? 0) + _amount(r);
    }
    final list = [
      for (final e in totals.entries)
        CategorySpending(
          name: _db.get(_cats, e.key)?['name'] as String? ?? 'Uncategorised',
          colorHex: _db.get(_cats, e.key)?['color_hex'] as String?,
          total: double.parse(e.value.toStringAsFixed(2)),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Future<Transaction> addTransaction(Map<String, dynamic> data) async {
    final record = await _db.save(_tx, _clean(data));
    return Transaction.fromJson(_withCategory(record));
  }

  Future<Transaction> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    final record = await _db.save(_tx, _clean(data), id: id);
    return Transaction.fromJson(_withCategory(record));
  }

  Future<void> deleteTransaction(String id) => _db.delete(_tx, id);

  /// Same shape whatever the screen sent: a plain date, a number, no blank note.
  Map<String, dynamic> _clean(Map<String, dynamic> data) {
    final note = (data['note'] as String?)?.trim();
    return {
      ...data,
      'amount': double.parse(data['amount'].toString()),
      'account': data['account'] ?? 'cash',
      'transaction_date': data['transaction_date'].toString().substring(0, 10),
      'note': note == null || note.isEmpty ? null : note,
    };
  }

  List<ExpenseCategory> fetchCategories() {
    final list = _db.all(_cats).map(ExpenseCategory.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<ExpenseCategory> createCategory(Map<String, dynamic> data) async {
    return ExpenseCategory.fromJson(await _db.save(_cats, data));
  }

  Future<ExpenseCategory> updateCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    return ExpenseCategory.fromJson(await _db.save(_cats, data, id: id));
  }

  /// Transactions keep their amounts; their category becomes empty.
  Future<void> deleteCategory(String id) async {
    await _db.saveAll(_tx, {
      for (final r in _db.all(_tx))
        if (r['category_id'] == id) r['id'] as String: {'category_id': null},
    });
    await _db.delete(_cats, id);
  }

  /// Daily income/expense totals for the last 7 days (bar chart):
  /// `[{transaction_date, type, total}]`.
  List<Map<String, dynamic>> fetchChartData() {
    final now = DateTime.now();
    final from = dateKey(DateTime(now.year, now.month, now.day - 6));
    final grouped = <String, Map<String, dynamic>>{};
    for (final r in _db.all(_tx)) {
      final date = r['transaction_date'] as String;
      if (date.compareTo(from) < 0) continue;
      final g = grouped.putIfAbsent(
        '${date}_${r['type']}',
        () => {'transaction_date': date, 'type': r['type'], 'total': 0.0},
      );
      g['total'] = (g['total'] as double) + _amount(r);
    }
    return grouped.values.toList();
  }

  static double _amount(Map<String, dynamic> r) =>
      double.parse(r['amount'].toString());
}
