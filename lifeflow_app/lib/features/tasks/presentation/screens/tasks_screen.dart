import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/task.dart';
import '../providers/task_provider.dart';

// Kanban lanes, in board order.
const _lanes = [
  (status: 'todo', title: 'To Do', color: Color(0xFF94A3B8)),
  (status: 'in_progress', title: 'In Progress', color: Color(0xFFFBBF24)),
  (status: 'done', title: 'Done', color: Color(0xFF34D399)),
];

/// Below this width the board shows one lane at a time with a switcher.
const _phoneBreakpoint = 700.0;

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _phoneLane = 'todo';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPhone = MediaQuery.sizeOf(context).width < _phoneBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Task Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!isPhone)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: () => _showAddTaskDialog(context, ref, theme),
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            ),
        ],
      ),
      floatingActionButton: isPhone
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTaskDialog(context, ref, theme),
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            )
          : null,
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load your tasks."),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(tasksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (tasks) {
          List<Task> inLane(String status) =>
              tasks.where((t) => t.status == status).toList();

          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_kanban_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Plan your first task',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add what you need to do, then move it from To Do to Done.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _showAddTaskDialog(context, ref, theme),
                      icon: const Icon(Icons.add),
                      label: const Text('New task'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (isPhone) {
            final lane = _lanes.firstWhere((l) => l.status == _phoneLane);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                      segments: [
                        for (final l in _lanes)
                          ButtonSegment(
                            value: l.status,
                            label: Text(
                              '${l.title} ${inLane(l.status).length}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      selected: {_phoneLane},
                      onSelectionChanged: (s) =>
                          setState(() => _phoneLane = s.first),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildColumn(
                      context,
                      ref,
                      lane.title,
                      lane.status,
                      inLane(lane.status),
                      lane.color,
                      isDark,
                      isPhone: true,
                    ),
                  ),
                ),
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in _lanes) ...[
                  if (l != _lanes.first) const SizedBox(width: 16),
                  Expanded(
                    child: _buildColumn(
                      context,
                      ref,
                      l.title,
                      l.status,
                      inLane(l.status),
                      l.color,
                      isDark,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be permanently removed.'),
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
    if (confirmed == true) ref.read(tasksProvider.notifier).deleteTask(task);
  }

  void _showAddTaskDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'New Task',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
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
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
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
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Due Date', style: theme.textTheme.labelLarge),
                    subtitle: Text(
                      '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          dueDate = picked;
                        });
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
                      setState(() {
                        priority = newSelection.first;
                      });
                    },
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
                    if (titleController.text.isNotEmpty) {
                      ref
                          .read(tasksProvider.notifier)
                          .addTask(
                            Task(
                              id: 0,
                              title: titleController.text,
                              description: descController.text,
                              status: 'todo',
                              priority: priority,
                              dueDate: dueDate,
                            ),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Create Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColumn(
    BuildContext context,
    WidgetRef ref,
    String title,
    String status,
    List<Task> columnTasks,
    Color indicatorColor,
    bool isDark, {
    bool isPhone = false,
  }) {
    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        final task = details.data;
        if (task.status != status) {
          ref.read(tasksProvider.notifier).updateTaskStatus(task, status);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? indicatorColor.withValues(alpha: 0.08)
                : indicatorColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? indicatorColor.withValues(alpha: 0.6)
                  : indicatorColor.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPhone)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: indicatorColor.withValues(
                      alpha: isDark ? 0.2 : 0.15,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${columnTasks.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: columnTasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            status == 'done'
                                ? 'Nothing finished yet.'
                                : 'No tasks here.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(tasksProvider.future),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          // Leave room so the floating "New task" button never covers the last card.
                          padding: EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            isPhone ? 88 : 12,
                          ),
                          itemCount: columnTasks.length,
                          itemBuilder: (context, index) {
                            final task = columnTasks[index];
                            final card = _buildTaskCard(
                              context,
                              ref,
                              task,
                              isDark,
                            );
                            // Touch screens scroll with drags, so lanes are switched via the card menu instead.
                            if (isPhone) return card;
                            return Draggable<Task>(
                              data: task,
                              feedback: Material(
                                elevation: 12,
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 260,
                                  child: _buildTaskCard(
                                    context,
                                    ref,
                                    task,
                                    isDark,
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.4,
                                child: card,
                              ),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.grab,
                                child: card,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    WidgetRef ref,
    Task task,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Task actions',
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                onSelected: (action) {
                  if (action == 'delete') {
                    _confirmDelete(task);
                  } else {
                    ref
                        .read(tasksProvider.notifier)
                        .updateTaskStatus(task, action);
                  }
                },
                itemBuilder: (context) => [
                  for (final l in _lanes)
                    if (l.status != task.status)
                      PopupMenuItem(
                        value: l.status,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 12, color: l.color),
                            const SizedBox(width: 12),
                            Text('Move to ${l.title}'),
                          ],
                        ),
                      ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
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
          if (task.description != null && task.description!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                _buildPriorityChip(task.priority),
                const Spacer(),
                if (task.dueDate != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.dueDate!.day}/${task.dueDate!.month}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'high':
        color = const Color(0xFFEF4444);
        break;
      case 'medium':
        color = const Color(0xFFF59E0B);
        break;
      default:
        color = const Color(0xFF3B82F6);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
