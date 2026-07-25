class HabitLog {
  final int id;
  final String completedDate;

  HabitLog({required this.id, required this.completedDate});

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'],
      completedDate: json['completed_date'],
    );
  }
}

class Habit {
  final int id;
  final String name;
  final String? colorHex;
  final int currentStreak;
  final int longestStreak;
  final List<HabitLog> logs;

  Habit({
    required this.id,
    required this.name,
    this.colorHex,
    required this.currentStreak,
    required this.longestStreak,
    required this.logs,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      name: json['name'],
      colorHex: json['color_hex'],
      currentStreak: json['current_streak'],
      longestStreak: json['longest_streak'],
      logs: json['logs'] != null ? (json['logs'] as List).map((l) => HabitLog.fromJson(l)).toList() : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'color_hex': colorHex,
  };
}
