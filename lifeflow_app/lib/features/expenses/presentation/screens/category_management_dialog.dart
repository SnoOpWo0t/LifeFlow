import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../domain/expense_models.dart';
import '../providers/expense_provider.dart';

const _palette = <Color>[
  Color(0xFFEF4444), // red
  Color(0xFFF97316), // orange
  Color(0xFFEAB308), // yellow
  Color(0xFF22C55E), // green
  Color(0xFF14B8A6), // teal
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
];

/// "#RRGGBB" → Color, falling back to grey for anything malformed.
Color categoryColor(String? hex) {
  final value = int.tryParse((hex ?? '').replaceFirst('#', ''), radix: 16);
  return value != null && (hex ?? '').length == 7
      ? Color(0xFF000000 | value)
      : Colors.grey;
}

String _toHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class CategoryManagementDialog extends ConsumerStatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  ConsumerState<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState
    extends ConsumerState<CategoryManagementDialog> {
  final _nameController = TextEditingController();
  String _selectedType = 'expense';
  Color _selectedColor = _palette[5];
  bool _isLoading = false;

  /// The category being edited, or null when creating a new one.
  ExpenseCategory? _editing;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _startEditing(ExpenseCategory category) {
    setState(() {
      _editing = category;
      _nameController.text = category.name;
      _selectedType = category.type;
      _selectedColor = categoryColor(category.colorHex);
    });
  }

  void _resetForm() {
    setState(() {
      _editing = null;
      _nameController.clear();
      _selectedType = 'expense';
      _selectedColor = _palette[5];
    });
  }

  void _refreshMoneyViews() {
    ref.invalidate(categoriesProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(dashboardSummaryProvider);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    final data = {
      'name': name,
      'type': _selectedType,
      // This used to always send "#", so picked colours were never saved.
      'color_hex': _toHex(_selectedColor),
    };
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final editing = _editing;
      if (editing == null) {
        await repo.createCategory(data);
        _showMessage('Category created');
      } else {
        await repo.updateCategory(editing.id, data);
        _showMessage('Category updated');
      }
      _refreshMoneyViews();
      _resetForm();
    } catch (_) {
      _showMessage("Couldn't save the category. Try again.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(ExpenseCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${category.name}" will be removed. Its transactions are kept but will have no category.',
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
    if (confirmed != true) return;
    try {
      await ref.read(expenseRepositoryProvider).deleteCategory(category.id);
      if (_editing?.id == category.id) _resetForm();
      _refreshMoneyViews();
    } catch (_) {
      _showMessage("Couldn't delete the category. Try again.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final editing = _editing;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage Categories',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: categoriesAsync.when(
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Text("Couldn't load categories.")),
                  ),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(
                            'No categories yet. Create one below.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final catColor = categoryColor(cat.colorHex);
                        return ListTile(
                          selected: editing?.id == cat.id,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: catColor.withValues(alpha: 0.2),
                            child: Icon(
                              cat.type == 'income'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: catColor,
                              size: 16,
                            ),
                          ),
                          title: Text(cat.name),
                          subtitle: Text(
                            cat.type == 'income' ? 'Income' : 'Expense',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit ${cat.name}',
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _startEditing(cat),
                              ),
                              IconButton(
                                tooltip: 'Delete ${cat.name}',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _delete(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                editing == null ? 'New category' : 'Edit "${editing.name}"',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _isLoading ? null : _save(),
                decoration: InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selection) =>
                      setState(() => _selectedType = selection.first),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in _palette)
                    Semantics(
                      button: true,
                      selected: _selectedColor == color,
                      label: 'Colour',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: _selectedColor == color
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (editing != null) ...[
                    TextButton(
                      onPressed: _isLoading ? null : _resetForm,
                      child: const Text('Cancel edit'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              editing == null
                                  ? 'Create category'
                                  : 'Save changes',
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
