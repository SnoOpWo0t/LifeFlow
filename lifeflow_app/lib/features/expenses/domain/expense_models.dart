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
