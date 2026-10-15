import 'package:flutter/material.dart';

class Saving {
  final String id;
  final double amount;
  final String type; // 'deposit' or 'withdrawal'
  final String account; // 'cash', 'bkash', 'nagad', 'bank'
  final String? note;
  final DateTime transactionDate;
  final DateTime? createdAt;

  Saving({
    required this.id,
    required this.amount,
    required this.type,
    this.account = 'cash',
    this.note,
    required this.transactionDate,
    this.createdAt,
  });

  bool get isDeposit => type == 'deposit';
  bool get isWithdrawal => type == 'withdrawal';

  factory Saving.fromJson(Map<String, dynamic> json) {
    return Saving(
      id: json['id'] as String,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      type: json['type'] as String? ?? 'deposit',
      account: json['account'] as String? ?? 'cash',
      note: json['note'] as String?,
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type,
      'account': account,
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      'transaction_date':
          "${transactionDate.year.toString().padLeft(4, '0')}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}",
    };
  }

  Saving copyWith({
    String? id,
    double? amount,
    String? type,
    String? account,
    String? note,
    DateTime? transactionDate,
    DateTime? createdAt,
  }) {
    return Saving(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      account: account ?? this.account,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SavingsAccountMeta {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const SavingsAccountMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  static const List<SavingsAccountMeta> accounts = [
    SavingsAccountMeta(
      key: 'bank',
      label: 'Bank',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF6366F1), // Indigo
    ),
    SavingsAccountMeta(
      key: 'bkash',
      label: 'bKash',
      icon: Icons.phone_android,
      color: Color(0xFFEC4899), // Pink
    ),
    SavingsAccountMeta(
      key: 'nagad',
      label: 'Nagad',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFF97316), // Orange
    ),
    SavingsAccountMeta(
      key: 'cash',
      label: 'Cash',
      icon: Icons.payments_outlined,
      color: Color(0xFF10B981), // Emerald
    ),
  ];

  static SavingsAccountMeta forAccount(String key) {
    return accounts.firstWhere(
      (a) => a.key == key.toLowerCase(),
      orElse: () => accounts.last, // default to cash
    );
  }
}

class SavingsSummary {
  final double totalSavings;
  final double totalDeposits;
  final double totalWithdrawals;
  final Map<String, double> byAccount;

  SavingsSummary({
    required this.totalSavings,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.byAccount,
  });
}
