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

    final isWide = MediaQuery.sizeOf(context).width >= 1000;
    void addHabit() => _showAddHabitDialog(context, ref, theme);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Habit Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: addHabit,
                icon: const Icon(Icons.add),
                label: const Text('Add habit'),
              ),
            ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(habitsProvider),
            child: const Text("Couldn't load habits. Tap to retry."),
          ),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Build your first habit',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Small daily actions add up. Check in each day to grow your streak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: addHabit,
                      icon: const Icon(Icons.add),
                      label: const Text('Add habit'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Two cards per row on wide screens; full-width cards on phones.
          final perRow = isWide ? 2 : 1;
          final rowCount = (habits.length / perRow).ceil();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(habitsProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              // Bottom padding keeps the floating "Add Habit" button off the last card.
              padding: EdgeInsets.fromLTRB(16, 16, 16, isWide ? 24 : 96),
              itemCount: rowCount,
              itemBuilder: (context, row) {
                if (perRow == 1) {
                  return _buildHabitCard(
                    context,
                    ref,
                    habits[row],
                    isDark,
                    theme,
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < perRow; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        child: row * perRow + i < habits.length
                            ? _buildHabitCard(
                                context,
                                ref,
                                habits[row * perRow + i],
                                isDark,
                                theme,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.extended(
              onPressed: addHabit,
              icon: const Icon(Icons.add),
              label: const Text('Add Habit'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Habit habit) {
    final controller = TextEditingController(text: habit.name);
    void save(BuildContext ctx) {
      final name = controller.text.trim();
      if (name.isEmpty) return;
      ref.read(habitsProvider.notifier).renameHabit(habit.id, name);
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Habit name'),
          onSubmitted: (_) => save(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () => save(ctx), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text(
          '"${habit.name}" and its check-in history will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true)
      ref.read(habitsProvider.notifier).deleteHabit(habit.id);
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
    // tryParse: a malformed colour (e.g. "#abc") used to throw and break the card.
    final parsedColor = int.tryParse(
      (habit.colorHex ?? '').replaceAll('#', ''),
      radix: 16,
    );
    final habitColor = parsedColor != null && (habit.colorHex ?? '').length == 7
        ? Color(0xFF000000 | parsedColor)
        : const Color(0xFF8B5CF6);

    final completedThisWeek = last7Days
        .where((d) => d['completed'] == true)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.cardTheme.color ??
                (isDark ? const Color(0xFF1E293B) : Colors.white),
            habitColor.withValues(alpha: isDark ? 0.15 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: habitColor.withValues(alpha: 0.3), width: 1),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTodayCompleted
                            ? 'Done for today. Nice!'
                            : habit.currentStreak > 0
                            ? 'Check in today to keep your ${habit.currentStreak}-day streak'
                            : habit.longestStreak > 0
                            ? 'Best streak: ${habit.longestStreak} days. Start a new one today'
                            : 'Start your streak today',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [habitColor.withValues(alpha: 0.8), habitColor],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: habitColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${habit.currentStreak}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Habit actions',
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (action) => action == 'rename'
                      ? _showRenameDialog(context, ref, habit)
                      : _confirmDelete(context, ref, habit),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 12),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weekly Progress',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$completedThisWeek/7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: habitColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: completedThisWeek / 7,
                backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                minHeight: 8,
              ),
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
