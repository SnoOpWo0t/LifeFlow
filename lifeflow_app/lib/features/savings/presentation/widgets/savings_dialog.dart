import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/savings_models.dart';
import '../providers/savings_provider.dart';

class SavingsDialog extends ConsumerStatefulWidget {
  final Saving? initialSaving;
  final String? defaultType; // 'deposit' or 'withdrawal'
  final String? defaultAccount;

  const SavingsDialog({
    super.key,
    this.initialSaving,
    this.defaultType,
    this.defaultAccount,
  });

  @override
  ConsumerState<SavingsDialog> createState() => _SavingsDialogState();
}

class _SavingsDialogState extends ConsumerState<SavingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late String _account;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSaving;
    _type = init?.type ?? widget.defaultType ?? 'deposit';
    _account = init?.account ?? widget.defaultAccount ?? 'bank';
    _amountController = TextEditingController(
      text: init != null ? init.amount.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: init?.note ?? '');
    _selectedDate = init?.transactionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      if (widget.initialSaving != null) {
        await ref.read(savingsListProvider.notifier).updateSaving(
          widget.initialSaving!.id,
          {
            'amount': amount,
            'type': _type,
            'account': _account,
            'transaction_date':
                "${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
            'note': _noteController.text.trim(),
          },
        );
      } else {
        await ref.read(savingsListProvider.notifier).addSaving(
              amount: amount,
              type: _type,
              account: _account,
              transactionDate: _selectedDate,
              note: _noteController.text.trim(),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.initialSaving == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text(
          'Are you sure you want to delete this savings entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(savingsListProvider.notifier)
          .deleteSaving(widget.initialSaving!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDeposit = _type == 'deposit';
    final accentColor =
        isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initialSaving != null
                                ? 'Edit Savings'
                                : (isDeposit ? 'Add to Savings' : 'Withdraw from Savings'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isDeposit
                                ? 'Store money into your savings vault'
                                : 'Take money out of your savings vault',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Deposit / Withdrawal Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = 'deposit'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isDeposit
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isDeposit
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.savings_outlined,
                                  size: 18,
                                  color: isDeposit
                                      ? Colors.white
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Deposit (Save)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDeposit
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _type = 'withdrawal'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isDeposit
                                  ? const Color(0xFFEF4444)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !isDeposit
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.outbox_outlined,
                                  size: 18,
                                  color: !isDeposit
                                      ? Colors.white
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: !isDeposit
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Account / Wallet selector (Bank, bKash, Nagad, Cash)
                Text(
                  'Select Wallet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: SavingsAccountMeta.accounts.map((acc) {
                    final isSelected = _account == acc.key;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _account = acc.key),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? acc.color.withValues(alpha: isDark ? 0.25 : 0.12)
                                : (isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? acc.color
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFE2E8F0)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                acc.icon,
                                color: isSelected
                                    ? acc.color
                                    : (isDark ? Colors.white54 : Colors.black45),
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                acc.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? acc.color
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  autofocus: widget.initialSaving == null,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (৳)',
                    prefixText: '৳ ',
                    prefixStyle: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    hintText: '0.00',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an amount';
                    }
                    final d = double.tryParse(val.trim());
                    if (d == null || d <= 0) {
                      return 'Amount must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Note Field
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note / Purpose (Optional)',
                    hintText: isDeposit
                        ? 'e.g. Monthly emergency fund deposit'
                        : 'e.g. Withdrawal for urgent car repair',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFCBD5E1),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    if (widget.initialSaving != null) ...[
                      IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        color: Theme.of(context).colorScheme.error,
                        tooltip: 'Delete',
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.initialSaving != null
                                  ? 'Update'
                                  : (isDeposit ? 'Save Money' : 'Withdraw'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
    );
  }
}
