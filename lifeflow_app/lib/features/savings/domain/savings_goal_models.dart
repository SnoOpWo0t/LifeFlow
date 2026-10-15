class SavingsGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final String? category;
  final String? colorHex;
  final bool isCompleted;
  final DateTime? createdAt;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.targetDate,
    this.category,
    this.colorHex,
    this.isCompleted = false,
    this.createdAt,
  });

  double get progressRatio {
    if (targetAmount <= 0) return 0.0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0);
  }

  double get remainingAmount =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity);

  int? get daysRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(
      targetDate!.year,
      targetDate!.month,
      targetDate!.day,
    );
    return target.difference(today).inDays;
  }

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Goal',
      targetAmount: double.tryParse(json['target_amount'].toString()) ?? 0.0,
      savedAmount: double.tryParse(json['saved_amount'].toString()) ?? 0.0,
      targetDate: json['target_date'] != null
          ? DateTime.tryParse(json['target_date'].toString())
          : null,
      category: json['category'] as String?,
      colorHex: json['color_hex'] as String?,
      isCompleted: json['is_completed'] == true ||
          json['is_completed'] == 1 ||
          json['is_completed'] == '1',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      if (targetDate != null)
        'target_date':
            "${targetDate!.year.toString().padLeft(4, '0')}-${targetDate!.month.toString().padLeft(2, '0')}-${targetDate!.day.toString().padLeft(2, '0')}",
      if (category != null && category!.trim().isNotEmpty)
        'category': category!.trim(),
      if (colorHex != null) 'color_hex': colorHex,
      'is_completed': isCompleted,
    };
  }

  SavingsGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    String? category,
    String? colorHex,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      colorHex: colorHex ?? this.colorHex,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
