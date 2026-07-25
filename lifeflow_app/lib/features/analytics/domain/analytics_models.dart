class DailyStats {
  final String dayName;
  final int tasksCompleted;
  final int habitsCompleted;
  final double expenses;
  final double income;
  final int productivityScore;

  DailyStats({
    required this.dayName,
    required this.tasksCompleted,
    required this.habitsCompleted,
    required this.expenses,
    required this.income,
    required this.productivityScore,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      dayName: json['day_name'],
      tasksCompleted: json['tasks_completed'],
      habitsCompleted: json['habits_completed'],
      expenses: (json['expenses'] as num).toDouble(),
      income: (json['income'] as num).toDouble(),
      productivityScore: json['productivity_score'],
    );
  }
}

class WeeklyAnalytics {
  final List<DailyStats> weeklyData;
  final double totalSavings;
  final String mostProductiveDay;
  final int maxProductivityScore;

  WeeklyAnalytics({
    required this.weeklyData,
    required this.totalSavings,
    required this.mostProductiveDay,
    required this.maxProductivityScore,
  });

  factory WeeklyAnalytics.fromJson(Map<String, dynamic> json) {
    var list = json['weekly_data'] as List? ?? [];
    List<DailyStats> dailyData = list.map((i) => DailyStats.fromJson(i)).toList();

    return WeeklyAnalytics(
      weeklyData: dailyData,
      totalSavings: (json['total_savings'] as num).toDouble(),
      mostProductiveDay: json['most_productive_day'],
      maxProductivityScore: json['max_productivity_score'],
    );
  }
}
