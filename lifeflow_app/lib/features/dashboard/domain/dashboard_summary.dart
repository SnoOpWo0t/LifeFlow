class RecentActivity {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final double? amount;
  final bool? isIncome;
  final DateTime date;

  RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.amount,
    this.isIncome,
    required this.date,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      subtitle: json['subtitle'],
      amount: json['amount'] != null
          ? (json['amount'] as num).toDouble()
          : null,
      isIncome: json['is_income'],
      date: DateTime.parse(json['date']),
    );
  }
}

class DashboardSummary {
  final int tasksCompleted;
  final int tasksTotal;
  final int habitsCompleted;
  final int habitsTotal;
  final double monthlyExpenses;
  final double monthlyIncome;
  final double monthlyBudget;
  final int productivityScore;
  final List<RecentActivity> recentActivity;

  DashboardSummary({
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.habitsCompleted,
    required this.habitsTotal,
    required this.monthlyExpenses,
    required this.monthlyIncome,
    required this.monthlyBudget,
    required this.productivityScore,
    required this.recentActivity,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    var list = json['recent_activity'] as List? ?? [];
    List<RecentActivity> activities = list
        .map((i) => RecentActivity.fromJson(i))
        .toList();

    return DashboardSummary(
      tasksCompleted: json['tasks_today']['completed'],
      tasksTotal: json['tasks_today']['total'],
      habitsCompleted: json['habits_today']['completed'],
      habitsTotal: json['habits_today']['total'],
      monthlyExpenses: (json['monthly_expenses'] as num).toDouble(),
      monthlyIncome: (json['monthly_income'] as num).toDouble(),
      monthlyBudget: json['monthly_budget'] != null
          ? (json['monthly_budget'] as num).toDouble()
          : 0.0,
      productivityScore: json['productivity_score'],
      recentActivity: activities,
    );
  }
}
