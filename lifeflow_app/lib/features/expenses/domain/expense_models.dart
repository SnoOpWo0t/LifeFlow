class ExpenseCategory {
  final int id;
  final String name;
  final String type;
  final String? colorHex;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.type,
    this.colorHex,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      colorHex: json['color_hex'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'color_hex': colorHex,
  };
}

class Transaction {
  final int id;
  final ExpenseCategory? category;
  final double amount;
  final String type;
  final DateTime transactionDate;
  final String? note;

  Transaction({
    required this.id,
    this.category,
    required this.amount,
    required this.type,
    required this.transactionDate,
    this.note,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      category: json['category'] != null
          ? ExpenseCategory.fromJson(json['category'])
          : null,
      // PostgreSQL returns decimals as strings, SQLite as numbers.
      amount: double.parse(json['amount'].toString()),
      type: json['type'],
      transactionDate: DateTime.parse(json['transaction_date']),
      note: json['note'],
    );
  }
}

/// One page of `GET /transactions` (the API returns 30 per page).
class TransactionPage {
  final List<Transaction> items;
  final bool hasMore;

  const TransactionPage(this.items, {required this.hasMore});

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return TransactionPage(
      (json['data'] as List).map((j) => Transaction.fromJson(j)).toList(),
      hasMore: (meta['current_page'] as num) < (meta['last_page'] as num),
    );
  }
}

/// Everything loaded so far, for infinite scrolling.
class TransactionFeed {
  final List<Transaction> items;
  final bool hasMore;
  final bool loadingMore;

  const TransactionFeed(
    this.items, {
    required this.hasMore,
    this.loadingMore = false,
  });

  TransactionFeed copyWith({bool? loadingMore}) => TransactionFeed(
    items,
    hasMore: hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// This month's spending in one category (from `GET /transactions/by-category`).
class CategorySpending {
  final String name;
  final String? colorHex;
  final double total;

  const CategorySpending({
    required this.name,
    this.colorHex,
    required this.total,
  });

  factory CategorySpending.fromJson(Map<String, dynamic> json) =>
      CategorySpending(
        name: json['name'] as String,
        colorHex: json['color_hex'] as String?,
        total: double.parse(json['total'].toString()),
      );
}
