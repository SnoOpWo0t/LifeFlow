class DashboardSummary {
  final int tasksCompleted;
  final int tasksTotal;
  final int habitsCompleted;
  final int habitsTotal;
  final double monthlyExpenses;
  final double monthlyIncome;
  final int productivityScore;

  DashboardSummary({
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.habitsCompleted,
    required this.habitsTotal,
    required this.monthlyExpenses,
    required this.monthlyIncome,
    required this.productivityScore,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      tasksCompleted: json['tasks_today']['completed'],
      tasksTotal: json['tasks_today']['total'],
      habitsCompleted: json['habits_today']['completed'],
      habitsTotal: json['habits_today']['total'],
      monthlyExpenses: (json['monthly_expenses'] as num).toDouble(),
      monthlyIncome: (json['monthly_income'] as num).toDouble(),
      productivityScore: json['productivity_score'],
    );
  }
}
