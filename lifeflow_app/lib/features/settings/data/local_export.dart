import 'dart:convert';

import '../../../core/local/local_db.dart';
import '../../../core/utils/dates.dart';
import '../../auth/domain/user.dart';

/// "Export my data", built on the device so it works offline and without an
/// account. Same layout as the server's export (minus AI summaries).
class LocalExporter {
  final LocalDb _db;

  LocalExporter(this._db);

  static Map<String, dynamic> _public(Map<String, dynamic> r) =>
      Map.of(r)..remove('_dirty');

  ({List<int> bytes, String filename, String mimeType}) export(
    String format, {
    required User user,
    required Map<String, dynamic> preferences,
  }) {
    final stamp = dateKey(DateTime.now());
    final categories = {for (final c in _db.all('categories')) c['id']: c};
    final transactions = _db.all('transactions')
      ..sort(
        (a, b) => (a['transaction_date'] as String).compareTo(
          b['transaction_date'] as String,
        ),
      );

    if (format == 'csv') {
      String cell(Object? v) {
        final s = '${v ?? ''}';
        return RegExp(r'[",\n\r]').hasMatch(s)
            ? '"${s.replaceAll('"', '""')}"'
            : s;
      }

      final lines = [
        'date,type,amount,category,note',
        for (final t in transactions)
          [
            t['transaction_date'],
            t['type'],
            t['amount'],
            categories[t['category_id']]?['name'],
            t['note'],
          ].map(cell).join(','),
      ];
      return (
        bytes: utf8.encode('${lines.join('\r\n')}\r\n'),
        filename: 'lifeflow-transactions-$stamp.csv',
        mimeType: 'text/csv',
      );
    }

    final logs = _db.all('habit_logs');
    final data = {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': user.isLocal
          ? {'name': null, 'email': null, 'account': false}
          : {'name': user.name, 'email': user.email},
      'preferences': preferences,
      'tasks': _db.all('tasks').map(_public).toList(),
      'habits': [
        for (final h in _db.all('habits'))
          {
            ..._public(h),
            'logs': [
              for (final l in logs)
                if (l['habit_id'] == h['id']) l['completed_date'],
            ]..sort(),
          },
      ],
      'categories': categories.values.map(_public).toList(),
      'transactions': [
        for (final t in transactions)
          {..._public(t), 'category': categories[t['category_id']]?['name']},
      ],
      'wishlist': _db.all('wishlist').map(_public).toList(),
    };
    return (
      bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      filename: 'lifeflow-export-$stamp.json',
      mimeType: 'application/json',
    );
  }
}
