import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/habit_models.dart';
import '../providers/habit_provider.dart';

class HabitScreen extends ConsumerWidget {
  const HabitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Habit Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(
              child: Text(
                'No habits yet. Add one!',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _buildHabitCard(context, ref, habit, isDark, theme);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHabitDialog(context, ref, theme),
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddHabitDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final nameController = TextEditingController();
    String selectedColor = '#8B5CF6'; // Default Purple

    final colors = {
      'Purple': '#8B5CF6',
      'Blue': '#3B82F6',
      'Green': '#10B981',
      'Orange': '#F59E0B',
      'Rose': '#F43F5E',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'New Habit',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Habit Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? Colors.black12
                          : Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Color Theme', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: colors.entries.map((entry) {
                      final isSelected = selectedColor == entry.value;
                      final colorHex = int.parse(
                        entry.value.replaceAll('#', '0xFF'),
                      );
                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedColor = entry.value),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(colorHex),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(
                                        colorHex,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      ref
                          .read(habitsProvider.notifier)
                          .addHabit(
                            Habit(
                              id: 0,
                              name: nameController.text,
                              colorHex: selectedColor,
                              currentStreak: 0,
                              longestStreak: 0,
                              logs: [],
                            ),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Create Habit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHabitCard(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    bool isDark,
    ThemeData theme,
  ) {
    // Generate the last 7 days
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final isCompleted = habit.logs.any((log) => log.completedDate == dateStr);
      return {'date': date, 'completed': isCompleted, 'dateStr': dateStr};
    });

    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final isTodayCompleted = habit.logs.any(
      (log) => log.completedDate == todayStr,
    );

    // Parse color
    Color habitColor = const Color(0xFF8B5CF6);
    if (habit.colorHex != null && habit.colorHex!.isNotEmpty) {
      habitColor = Color(int.parse(habit.colorHex!.replaceAll('#', '0xFF')));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: habitColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    habit.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        color: habitColor,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${habit.currentStreak}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: habitColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: last7Days.map((dayData) {
                final date = dayData['date'] as DateTime;
                final isCompleted = dayData['completed'] as bool;
                final isToday = dayData['dateStr'] == todayStr;

                return Column(
                  children: [
                    Text(
                      _getWeekday(date.weekday),
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? habitColor : Colors.grey,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: isToday
                          ? () => ref
                                .read(habitsProvider.notifier)
                                .toggleHabit(habit.id)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? habitColor
                              : (isDark ? Colors.white12 : Colors.grey[200]),
                          border: isToday && !isCompleted
                              ? Border.all(color: habitColor, width: 2)
                              : null,
                          boxShadow: isCompleted
                              ? [
                                  BoxShadow(
                                    color: habitColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'M';
      case 2:
        return 'T';
      case 3:
        return 'W';
      case 4:
        return 'T';
      case 5:
        return 'F';
      case 6:
        return 'S';
      case 7:
        return 'S';
      default:
        return '';
    }
  }
}
