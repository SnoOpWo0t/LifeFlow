import '../../../core/local/local_db.dart';
import '../domain/savings_models.dart';

class SavingsRepository {
  final LocalDb _db;
  static const _store = 'savings';

  SavingsRepository(this._db);

  /// Fetch all active savings records, newest transaction_date first.
  List<Saving> fetchSavings() {
    final rows = _db.all(_store)
      ..sort((a, b) {
        final dateA = '${a['transaction_date'] ?? ''}';
        final dateB = '${b['transaction_date'] ?? ''}';
        final dateCmp = dateB.compareTo(dateA);
        if (dateCmp != 0) return dateCmp;
        return '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}');
      });

    return rows.map(Saving.fromJson).toList();
  }

  Future<Saving> createSaving(Map<String, dynamic> data) async {
    final record = await _db.save(_store, data);
    return Saving.fromJson(record);
  }

  Future<Saving> updateSaving(String id, Map<String, dynamic> data) async {
    final record = await _db.save(_store, data, id: id);
    return Saving.fromJson(record);
  }

  Future<void> deleteSaving(String id) => _db.delete(_store, id);

  SavingsSummary computeSummary() {
    final items = fetchSavings();
    final Map<String, double> byAccount = {
      'bank': 0.0,
      'bkash': 0.0,
      'nagad': 0.0,
      'cash': 0.0,
    };

    double totalDeposits = 0.0;
    double totalWithdrawals = 0.0;

    for (final s in items) {
      final acc = s.account.toLowerCase();
      if (!byAccount.containsKey(acc)) {
        byAccount[acc] = 0.0;
      }
      if (s.isDeposit) {
        byAccount[acc] = (byAccount[acc] ?? 0.0) + s.amount;
        totalDeposits += s.amount;
      } else {
        byAccount[acc] = (byAccount[acc] ?? 0.0) - s.amount;
        totalWithdrawals += s.amount;
      }
    }

    final totalSavings = totalDeposits - totalWithdrawals;

    return SavingsSummary(
      totalSavings: totalSavings,
      totalDeposits: totalDeposits,
      totalWithdrawals: totalWithdrawals,
      byAccount: byAccount,
    );
  }
}
