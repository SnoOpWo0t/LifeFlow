import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../expenses/presentation/screens/category_management_dialog.dart'
    show categoryColor;
import '../../domain/calendar_models.dart';
import '../providers/calendar_provider.dart';

const _taskColor = Colors.purpleAccent;
const _habitsAllDoneColor = Colors.green;
const _habitsSomeDoneColor = Colors.orangeAccent;
const _spendingColor = Colors.redAccent;

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Month-at-a-glance calendar for the dashboard: a dot for tasks due, habits
/// checked and money spent on each day, and the selected day's details below.
///
/// [compact] (phones): shows only the selected week until the user expands it.
class DashboardCalendar extends ConsumerStatefulWidget {
  const DashboardCalendar({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<DashboardCalendar> createState() => _DashboardCalendarState();
}

class _DashboardCalendarState extends ConsumerState<DashboardCalendar> {
  late DateTime _month;
  late DateTime _selected;
  bool _expanded = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selected = _today;
    _month = DateTime(_selected.year, _selected.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final isCurrentMonth =
          _month.year == _today.year && _month.month == _today.month;
      _selected = isCurrentMonth ? _today : _month;
    });
  }

  void _goToToday() {
    setState(() {
      _selected = _today;
      _month = DateTime(_today.year, _today.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthAsync = ref.watch(calendarMonthProvider(_month));
    final summary = monthAsync.value;
    final grid = monthGrid(_month);
    final collapsed = widget.compact && !_expanded;

    // Collapsed: only the week containing the selected day.
    final selectedIndex = grid.indexWhere((d) => _sameDay(d, _selected));
    final weekStart = collapsed
        ? (selectedIndex < 0 ? 0 : selectedIndex ~/ 7) * 7
        : 0;
    final visibleDays = collapsed
        ? grid.sublist(weekStart, weekStart + 7)
        : grid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_months[_month.month - 1]} ${_month.year}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!_sameDay(_selected, _today))
              TextButton(onPressed: _goToToday, child: const Text('Today')),
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final name in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    widget.compact ? name.substring(0, 1) : name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < visibleDays.length ~/ 7; row++)
          Row(
            children: [
              for (final day in visibleDays.sublist(row * 7, row * 7 + 7))
                Expanded(child: _buildDay(context, day, summary)),
            ],
          ),
        if (widget.compact)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less),
              label: Text(collapsed ? 'Show month' : 'Show week'),
            ),
          )
        else
          const SizedBox(height: 8),
        const _Legend(),
        const Divider(height: 24),
        _DayDetails(day: _selected),
      ],
    );
  }

  Widget _buildDay(BuildContext context, DateTime day, CalendarMonth? summary) {
    final theme = Theme.of(context);
    final inMonth = day.month == _month.month;
    final isSelected = _sameDay(day, _selected);
    final isToday = _sameDay(day, _today);
    final activity = summary?.days[dateKey(day)];

    final dots = <Color>[
      if ((activity?.tasksDue ?? 0) > 0) _taskColor,
      if ((activity?.habitsDone ?? 0) > 0)
        activity!.habitsDone >= summary!.habitsTotal
            ? _habitsAllDoneColor
            : _habitsSomeDoneColor,
      if ((activity?.spent ?? 0) > 0) _spendingColor,
    ];

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${day.day} ${_months[day.month - 1]}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selected = day;
          if (!inMonth) _month = DateTime(day.year, day.month);
        }),
        child: Container(
          height: widget.compact ? 46 : 52,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: isToday || isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : inMonth
                      ? null
                      : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in dots)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        item(_taskColor, 'Tasks due'),
        item(_habitsAllDoneColor, 'All habits'),
        item(_habitsSomeDoneColor, 'Some habits'),
        item(_spendingColor, 'Spending'),
      ],
    );
  }
}

/// Tasks, habits and transactions for the selected day.
class _DayDetails extends ConsumerWidget {
  const _DayDetails({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(calendarDayProvider(day));
    final title =
        '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1].substring(0, 3)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        detailAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(calendarDayProvider(day)),
            child: const Text("Couldn't load this day. Tap to retry."),
          ),
          data: (detail) {
            if (detail.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nothing planned or recorded on this day.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final task in detail.tasks)
                  _row(
                    icon: task.status == 'done'
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: _taskColor,
                    text: task.title,
                    struck: task.status == 'done',
                  ),
                if (detail.habits.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final habit in detail.habits)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            habit.done ? Icons.check : Icons.close,
                            size: 16,
                            color: habit.done
                                ? categoryColor(habit.colorHex)
                                : Colors.grey,
                          ),
                          label: Text(habit.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                for (final tx in detail.transactions)
                  _row(
                    icon: tx.type == 'income'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: tx.type == 'income' ? Colors.green : _spendingColor,
                    text: tx.note?.isNotEmpty == true
                        ? tx.note!
                        : (tx.category?.name ?? 'Transaction'),
                    trailing:
                        '${tx.type == 'income' ? '+' : '-'}${formatMoney(tx.amount)}',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String text,
    String? trailing,
    bool struck = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: struck ? TextDecoration.lineThrough : null,
                color: struck ? Colors.grey : null,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
