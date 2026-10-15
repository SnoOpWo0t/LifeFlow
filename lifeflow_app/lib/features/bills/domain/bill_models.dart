import 'package:flutter/material.dart';

class Bill {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String frequency; // 'monthly', 'weekly', 'quarterly', 'yearly', 'one_time'
  final String account; // 'bank', 'bkash', 'nagad', 'cash'
  final bool isPaid;
  final DateTime? lastPaidAt;
  final String? note;
  final String? categoryId;
  final DateTime? createdAt;

  Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.frequency = 'monthly',
    this.account = 'bank',
    this.isPaid = false,
    this.lastPaidAt,
    this.note,
    this.categoryId,
    this.createdAt,
  });

  bool get isRecurring => frequency != 'one_time';

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  bool get isOverdue => !isPaid && daysUntilDue < 0;
  bool get isDueToday => !isPaid && daysUntilDue == 0;
  bool get isDueSoon => !isPaid && daysUntilDue > 0 && daysUntilDue <= 3;

  String get dueStatusText {
    if (isPaid) {
      if (lastPaidAt != null) {
        return 'Paid on ${lastPaidAt!.day}/${lastPaidAt!.month}';
      }
      return 'Paid';
    }
    final days = daysUntilDue;
    if (days < 0) return 'Overdue by ${-days} ${-days == 1 ? "day" : "days"}';
    if (days == 0) return 'Due today!';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  Color get statusColor {
    if (isPaid) return const Color(0xFF10B981);
    if (isOverdue) return Colors.redAccent;
    if (isDueToday || isDueSoon) return Colors.amber;
    return const Color(0xFF6366F1);
  }

  String get frequencyLabel {
    return switch (frequency) {
      'weekly' => 'Weekly',
      'quarterly' => 'Quarterly',
      'yearly' => 'Yearly',
      'one_time' => 'One-time',
      _ => 'Monthly',
    };
  }

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Bill',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      frequency: json['frequency'] as String? ?? 'monthly',
      account: json['account'] as String? ?? 'bank',
      isPaid: json['is_paid'] == true ||
          json['is_paid'] == 1 ||
          json['is_paid'] == '1',
      lastPaidAt: json['last_paid_at'] != null
          ? DateTime.tryParse(json['last_paid_at'].toString())
          : null,
      note: json['note'] as String?,
      categoryId: json['category_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'due_date':
          "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}",
      'frequency': frequency,
      'account': account,
      'is_paid': isPaid,
      if (lastPaidAt != null)
        'last_paid_at':
            "${lastPaidAt!.year.toString().padLeft(4, '0')}-${lastPaidAt!.month.toString().padLeft(2, '0')}-${lastPaidAt!.day.toString().padLeft(2, '0')}",
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      if (categoryId != null) 'category_id': categoryId,
    };
  }

  Bill copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    String? frequency,
    String? account,
    bool? isPaid,
    DateTime? lastPaidAt,
    String? note,
    String? categoryId,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      frequency: frequency ?? this.frequency,
      account: account ?? this.account,
      isPaid: isPaid ?? this.isPaid,
      lastPaidAt: lastPaidAt ?? this.lastPaidAt,
      note: note ?? this.note,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
