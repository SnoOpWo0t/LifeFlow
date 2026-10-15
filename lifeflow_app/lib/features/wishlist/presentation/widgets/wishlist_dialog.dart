import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/wishlist_item.dart';
import '../../domain/wishlist_category_utils.dart';
import '../providers/wishlist_provider.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/utils/formatters.dart';

/// Shows the dialog to create or edit a Wishlist item.
Future<void> showWishlistDialog(
  BuildContext context, {
  WishlistItem? existing,
}) {
  return showDialog(
    context: context,
    builder: (context) => _WishlistFormDialog(existing: existing),
  );
}

class _WishlistFormDialog extends ConsumerStatefulWidget {
  final WishlistItem? existing;

  const _WishlistFormDialog({this.existing});

  @override
  ConsumerState<_WishlistFormDialog> createState() =>
      _WishlistFormDialogState();
}

class _WishlistFormDialogState extends ConsumerState<_WishlistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _linkController;
  late final TextEditingController _noteController;
  late String _priority;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _priceController = TextEditingController(
      text: widget.existing?.estimatedPrice != null
          ? (widget.existing!.estimatedPrice! % 1 == 0
                ? widget.existing!.estimatedPrice!.toInt().toString()
                : widget.existing!.estimatedPrice!.toString())
          : '',
    );
    _categoryController = TextEditingController(
      text: widget.existing?.category ?? '',
    );
    _linkController = TextEditingController(text: widget.existing?.link ?? '');
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _priority = widget.existing?.priority ?? 'normal';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim();
    final rawPrice = _priceController.text.replaceAll(',', '').trim();
    final double? estimatedPrice = rawPrice.isNotEmpty
        ? double.tryParse(rawPrice)
        : null;
    final category = _categoryController.text.trim();
    final link = _linkController.text.trim();
    final note = _noteController.text.trim();

    final data = <String, dynamic>{
      'title': title,
      'priority': _priority,
      'category': category.isNotEmpty ? category : null,
      'link': link.isNotEmpty ? link : null,
      'note': note.isNotEmpty ? note : null,
    };
    if (estimatedPrice != null) {
      data['estimated_price'] = estimatedPrice;
    }

    try {
      if (widget.existing != null) {
        await ref
            .read(wishlistProvider.notifier)
            .updateItem(widget.existing!.id, data);
      } else {
        await ref.read(wishlistProvider.notifier).addItem(data);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existing != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEditing ? Icons.edit_note : Icons.card_giftcard,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Wishlist Item' : 'New Wishlist Item',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Title field
                TextFormField(
                  controller: _titleController,
                  autofocus: !isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'What do you wish for? *',
                    hintText: 'e.g., Mechanical Keyboard, Kindle, Trip...',
                    prefixIcon: const Icon(Icons.star_outline, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Estimated Price
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Estimated Price (optional)',
                    hintText: 'e.g., 4,500',
                    prefixIcon: const Icon(Icons.attach_money, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    final num = double.tryParse(val.replaceAll(',', '').trim());
                    if (num == null || num < 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Custom Category
                Row(
                  children: [
                    Text(
                      'Category',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(optional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Category / Tag',
                    hintText: 'e.g., Perfume, Tech, Fashion, Books...',
                    prefixIcon: Icon(
                      WishlistCategoryUtils.getIcon(
                        _categoryController.text.trim(),
                      ),
                      color: _categoryController.text.trim().isNotEmpty
                          ? WishlistCategoryUtils.getColor(
                              _categoryController.text.trim(),
                            )
                          : null,
                      size: 20,
                    ),
                    suffixIcon: _categoryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _categoryController.clear()),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Quick suggestion chips
                Consumer(
                  builder: (context, ref, child) {
                    final existingCats = ref.watch(wishlistCategoriesProvider);
                    final allSuggestions = <String>{
                      ...WishlistCategoryUtils.popularCategories,
                      ...existingCats,
                    }.toList();

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: allSuggestions.map((cat) {
                          final isSelected =
                              _categoryController.text.trim().toLowerCase() ==
                              cat.toLowerCase();
                          final color = WishlistCategoryUtils.getColor(cat);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected ? color : null,
                                ),
                              ),
                              avatar: Icon(
                                WishlistCategoryUtils.getIcon(cat),
                                size: 14,
                                color: isSelected ? color : Colors.grey,
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _categoryController.text = selected
                                      ? cat
                                      : '';
                                });
                              },
                              selectedColor: color.withValues(
                                alpha: isDark ? 0.25 : 0.15,
                              ),
                              checkmarkColor: color,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? color
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Priority selector
                Text(
                  'Priority',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPriorityOption(
                      label: 'Low',
                      value: 'low',
                      icon: Icons.south,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityOption(
                      label: 'Normal',
                      value: 'normal',
                      icon: Icons.remove,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityOption(
                      label: 'High',
                      value: 'high',
                      icon: Icons.north,
                      color: const Color(0xFFF43F5E),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Link / Store URL
                TextFormField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Link / Store URL (optional)',
                    hintText: 'https://...',
                    prefixIcon: const Icon(Icons.link, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes / Reason to buy (optional)',
                    hintText: 'Specifications, why you want it, target date...',
                    prefixIcon: const Icon(Icons.notes, size: 20),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEditing ? 'Save Changes' : 'Add to Wishlist'),
        ),
      ],
    );
  }

  Widget _buildPriorityOption({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _priority == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _priority = value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? Colors.black12 : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper to convert a purchased wishlist item into an expense transaction!
Future<void> showConvertToExpenseDialog(
  BuildContext context, {
  required WidgetRef ref,
  required WishlistItem item,
}) {
  return showDialog(
    context: context,
    builder: (context) => _ConvertToExpenseDialog(item: item),
  );
}

class _ConvertToExpenseDialog extends ConsumerStatefulWidget {
  final WishlistItem item;

  const _ConvertToExpenseDialog({required this.item});

  @override
  ConsumerState<_ConvertToExpenseDialog> createState() =>
      _ConvertToExpenseDialogState();
}

class _ConvertToExpenseDialogState
    extends ConsumerState<_ConvertToExpenseDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  int? _selectedCategoryId;
  String _selectedAccount = 'cash';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.item.estimatedPrice != null
          ? (widget.item.estimatedPrice! % 1 == 0
                ? widget.item.estimatedPrice!.toInt().toString()
                : widget.item.estimatedPrice!.toString())
          : '',
    );
    _noteController = TextEditingController(
      text: 'Wishlist: ${widget.item.title}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.addTransaction({
        'amount': amount,
        'note': _noteController.text.trim(),
        'type': 'expense',
        'account': _selectedAccount,
        'category_id': _selectedCategoryId,
        'transaction_date': DateTime.now().toIso8601String(),
      });

      // Mark wishlist item as purchased if not already
      if (!widget.item.isPurchased) {
        await ref.read(wishlistProvider.notifier).togglePurchased(widget.item);
      }

      // Invalidate relevant providers to update the dashboard & expenses immediately
      ref.invalidate(transactionsProvider);
      ref.invalidate(chartDataProvider);
      ref.invalidate(spendingByCategoryProvider);
      ref.invalidate(dashboardSummaryProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded "${widget.item.title}" (${formatMoney(amount)}) to your $_selectedAccount wallet!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Record as Expense',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Congratulations on getting this item! Record the purchase in your LifeFlow wallet so your expenses stay accurate.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),

              // Actual Amount Paid
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount Paid *',
                  prefixIcon: const Icon(Icons.attach_money, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Account Selector
              _buildAccountPicker(
                theme: theme,
                selectedAccount: _selectedAccount,
                onChanged: (val) => setState(() => _selectedAccount = val),
              ),
              const SizedBox(height: 14),

              // Category dropdown
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const SizedBox(),
                data: (categories) {
                  final expenseCats = categories
                      .where((c) => c.type == 'expense')
                      .toList();

                  int? effectiveCategory = _selectedCategoryId;
                  if (effectiveCategory == null &&
                      widget.item.category != null &&
                      widget.item.category!.trim().isNotEmpty) {
                    final itemCatLower = widget.item.category!
                        .trim()
                        .toLowerCase();
                    final match = expenseCats
                        .where(
                          (c) => c.name.trim().toLowerCase() == itemCatLower,
                        )
                        .firstOrNull;
                    if (match != null) {
                      effectiveCategory = match.id;
                      _selectedCategoryId = match.id;
                    }
                  }

                  return DropdownButtonFormField<int?>(
                    initialValue: effectiveCategory,
                    decoration: InputDecoration(
                      labelText: 'Category (optional)',
                      prefixIcon: const Icon(Icons.category, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Uncategorized'),
                      ),
                      ...expenseCats.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Note
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note',
                  prefixIcon: const Icon(Icons.note, size: 20),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save Expense'),
        ),
      ],
    );
  }

  Widget _buildAccountPicker({
    required ThemeData theme,
    required String selectedAccount,
    required void Function(String) onChanged,
  }) {
    const options = [
      (value: 'cash', label: 'Cash', icon: Icons.wallet),
      (value: 'bkash', label: 'bKash', icon: Icons.phone_android),
      (value: 'nagad', label: 'Nagad', icon: Icons.flash_on),
      (value: 'bank', label: 'Bank', icon: Icons.account_balance),
    ];

    const accountColors = {
      'cash': Color(0xFF34D399),
      'bkash': Color(0xFFEC4899),
      'nagad': Color(0xFFF59E0B),
      'bank': Color(0xFF60A5FA),
    };

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Account / Wallet',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSelected = selectedAccount == opt.value;
            final color = accountColors[opt.value]!;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onChanged(opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                          : (isDark ? Colors.black12 : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 16,
                          color: isSelected ? color : Colors.grey,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? color : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
