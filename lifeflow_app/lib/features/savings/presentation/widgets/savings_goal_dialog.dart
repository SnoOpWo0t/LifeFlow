import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/savings_goal_models.dart';
import '../providers/savings_goals_provider.dart';

class SavingsGoalDialog extends ConsumerStatefulWidget {
  final SavingsGoal? existingGoal;

  const SavingsGoalDialog({super.key, this.existingGoal});

  @override
  ConsumerState<SavingsGoalDialog> createState() => _SavingsGoalDialogState();
}

class _SavingsGoalDialogState extends ConsumerState<SavingsGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _savedAmountController;
  late final TextEditingController _categoryController;
  DateTime? _targetDate;
  late String _selectedColor;

  static const List<String> _colorPresets = [
    '#6366F1', // Indigo
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#8B5CF6', // Purple
  ];

  static const List<String> _categoryPresets = [
    'Emergency',
    'Tech & Gadgets',
    'Travel',
    'Vehicle',
    'Education',
    'Investment',
    'Home',
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _targetAmountController = TextEditingController(
      text: goal != null && goal.targetAmount > 0
          ? goal.targetAmount.toStringAsFixed(0)
          : '',
    );
    _savedAmountController = TextEditingController(
      text: goal != null && goal.savedAmount > 0
          ? goal.savedAmount.toStringAsFixed(0)
          : '0',
    );
    _categoryController = TextEditingController(text: goal?.category ?? '');
    _targetDate = goal?.targetDate;
    _selectedColor = goal?.colorHex ?? _colorPresets.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _savedAmountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existingGoal != null;

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _parseColor(_selectedColor).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.flag_outlined,
              color: _parseColor(_selectedColor),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Savings Goal' : 'New Savings Goal',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g. MacBook Pro, Trip to Cox\'s Bazar',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black12 : Colors.grey[100],
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a goal title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _targetAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Target (৳)',
                          prefixIcon: const Icon(Icons.flag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black12 : Colors.grey[100],
                        ),
                        validator: (val) {
                          final parsed = double.tryParse(val ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter valid target';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _savedAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Already Saved (৳)',
                          prefixIcon: const Icon(Icons.savings_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black12 : Colors.grey[100],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Target Date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate ??
                          DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _targetDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _targetDate == null
                                ? 'Target Date (Optional)'
                                : 'Target: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                            style: TextStyle(
                              color: _targetDate == null ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (_targetDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _targetDate = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Category Presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in _categoryPresets)
                      ChoiceChip(
                        label: Text(preset, style: const TextStyle(fontSize: 11)),
                        selected: _categoryController.text == preset,
                        onSelected: (selected) {
                          setState(() {
                            _categoryController.text = selected ? preset : '';
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Color Presets
                Row(
                  children: [
                    const Text(
                      'Color: ',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    for (final colorHex in _colorPresets)
                      GestureDetector(
                        onTap: () => setState(() => _selectedColor = colorHex),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _parseColor(colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == colorHex
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (_selectedColor == colorHex)
                                BoxShadow(
                                  color: _parseColor(colorHex).withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (isEditing)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            onPressed: () async {
              await ref
                  .read(savingsGoalsListProvider.notifier)
                  .deleteGoal(widget.existingGoal!.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;

            final targetAmount =
                double.tryParse(_targetAmountController.text) ?? 0.0;
            final savedAmount =
                double.tryParse(_savedAmountController.text) ?? 0.0;

            if (isEditing) {
              await ref.read(savingsGoalsListProvider.notifier).updateGoal(
                widget.existingGoal!.id,
                {
                  'title': _titleController.text.trim(),
                  'target_amount': targetAmount,
                  'saved_amount': savedAmount,
                  'target_date': _targetDate != null
                      ? "${_targetDate!.year.toString().padLeft(4, '0')}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}"
                      : null,
                  'category': _categoryController.text.trim().isNotEmpty
                      ? _categoryController.text.trim()
                      : null,
                  'color_hex': _selectedColor,
                  'is_completed': savedAmount >= targetAmount && targetAmount > 0,
                },
              );
            } else {
              await ref.read(savingsGoalsListProvider.notifier).addGoal(
                title: _titleController.text.trim(),
                targetAmount: targetAmount,
                savedAmount: savedAmount,
                targetDate: _targetDate,
                category: _categoryController.text.trim().isNotEmpty
                    ? _categoryController.text.trim()
                    : null,
                colorHex: _selectedColor,
              );
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEditing
                        ? 'Savings goal updated!'
                        : 'Savings goal created!',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Text(isEditing ? 'Save Changes' : 'Create Goal'),
        ),
      ],
    );
  }
}
