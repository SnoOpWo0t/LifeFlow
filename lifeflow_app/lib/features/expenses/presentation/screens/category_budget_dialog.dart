import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/expense_provider.dart';
import 'category_management_dialog.dart' show categoryColor;

class CategoryBudgetDialog extends ConsumerStatefulWidget {
  const CategoryBudgetDialog({super.key});

  @override
  ConsumerState<CategoryBudgetDialog> createState() =>
      _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends ConsumerState<CategoryBudgetDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);
    final currentBudgets = ref.watch(categoryBudgetsProvider);

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pie_chart_outline, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'Category Budgets',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: categoriesAsync.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load categories: $err'),
          ),
          data: (allCategories) {
            final expenseCategories = allCategories
                .where((c) => c.type == 'expense')
                .toList();

            if (expenseCategories.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No expense categories found. Create categories first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            for (final cat in expenseCategories) {
              if (!_controllers.containsKey(cat.name)) {
                final currentVal = currentBudgets[cat.name];
                _controllers[cat.name] = TextEditingController(
                  text: currentVal != null && currentVal > 0
                      ? currentVal.toStringAsFixed(0)
                      : '',
                );
              }
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set monthly spending limits for each category. You will get alerts when spending reaches 80% and 100%.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final cat in expenseCategories) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: categoryColor(cat.colorHex),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: _controllers[cat.name],
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                prefixText: '৳ ',
                                hintText: 'No limit',
                                hintStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.black12
                                    : Colors.grey[100],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
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
            final notifier = ref.read(categoryBudgetsProvider.notifier);
            for (final entry in _controllers.entries) {
              final val = double.tryParse(entry.value.text.trim()) ?? 0.0;
              await notifier.setBudget(entry.key, val);
            }
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Category budgets updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text('Save Limits'),
        ),
      ],
    );
  }
}
