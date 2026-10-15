class ExpenseCategory {
  final String id;
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
      id: json['id'] as String,
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
  final String id;
  final ExpenseCategory? category;
  final double amount;
  final String type;
  final String account;
  final DateTime transactionDate;
  final String? note;

  Transaction({
    required this.id,
    this.category,
    required this.amount,
    required this.type,
    this.account = 'cash',
    required this.transactionDate,
    this.note,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      category: json['category'] != null
          ? ExpenseCategory.fromJson(json['category'])
          : null,
      amount: double.parse(json['amount'].toString()),
      type: json['type'],
      account: json['account'] as String? ?? 'cash',
      transactionDate: DateTime.parse(json['transaction_date']),
      note: json['note'],
    );
  }
}

/// One page of transactions (30 at a time, newest first).
class TransactionPage {
  final List<Transaction> items;
  final bool hasMore;

  const TransactionPage(this.items, {required this.hasMore});
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

/// This month's spending in one category.
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
