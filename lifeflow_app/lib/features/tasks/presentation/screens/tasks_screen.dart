import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../domain/task.dart';
import '../providers/task_provider.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Task Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => _showAddTaskDialog(context, ref, theme),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (tasks) {
            final todoTasks = tasks.where((t) => t.status == 'todo').toList();
            final inProgressTasks = tasks.where((t) => t.status == 'in_progress').toList();
            final doneTasks = tasks.where((t) => t.status == 'done').toList();

            final isMobile = MediaQuery.of(context).size.width < 600;

            return Padding(
              padding: const EdgeInsets.only(top: 100, bottom: 24, left: 16, right: 16),
              child: isMobile
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(width: 280, child: _buildColumn(context, ref, 'To Do', 'todo', todoTasks, const Color(0xFF94A3B8), isDark)),
                        const SizedBox(width: 16),
                        SizedBox(width: 280, child: _buildColumn(context, ref, 'In Progress', 'in_progress', inProgressTasks, const Color(0xFFFBBF24), isDark)),
                        const SizedBox(width: 16),
                        SizedBox(width: 280, child: _buildColumn(context, ref, 'Done', 'done', doneTasks, const Color(0xFF34D399), isDark)),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(child: _buildColumn(context, ref, 'To Do', 'todo', todoTasks, const Color(0xFF94A3B8), isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildColumn(context, ref, 'In Progress', 'in_progress', inProgressTasks, const Color(0xFFFBBF24), isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildColumn(context, ref, 'Done', 'done', doneTasks, const Color(0xFF34D399), isDark)),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref, ThemeData theme) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'medium';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('New Task', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Due Date', style: theme.textTheme.labelLarge),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() { dueDate = picked; });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Priority', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Low')),
                      ButtonSegment(value: 'medium', label: Text('Medium')),
                      ButtonSegment(value: 'high', label: Text('High')),
                    ],
                    selected: {priority},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() { priority = newSelection.first; });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      ref.read(tasksProvider.notifier).addTask(
                        Task(id: 0, title: titleController.text, description: descController.text, status: 'todo', priority: priority, dueDate: dueDate)
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Create Task'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildColumn(BuildContext context, WidgetRef ref, String title, String status, List<Task> columnTasks, Color indicatorColor, bool isDark) {
    return DragTarget<Task>(
      onAccept: (task) {
        if (task.status != status) {
          ref.read(tasksProvider.notifier).updateTaskStatus(task, status);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? indicatorColor.withOpacity(0.08) : indicatorColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: candidateData.isNotEmpty ? indicatorColor.withOpacity(0.6) : indicatorColor.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: indicatorColor.withOpacity(isDark ? 0.2 : 0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${columnTasks.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: columnTasks.length,
                  itemBuilder: (context, index) {
                    final task = columnTasks[index];
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 12,
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.transparent,
                        child: SizedBox(width: 260, child: _buildTaskCard(context, task, isDark)),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildTaskCard(context, task, isDark),
                      ),
                      child: _buildTaskCard(context, task, isDark),
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ],
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPriorityChip(task.priority),
              const Spacer(),
              if (task.dueDate != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${task.dueDate!.day}/${task.dueDate!.month}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'high': color = const Color(0xFFEF4444); break;
      case 'medium': color = const Color(0xFFF59E0B); break;
      default: color = const Color(0xFF3B82F6); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
    );
  }
}
