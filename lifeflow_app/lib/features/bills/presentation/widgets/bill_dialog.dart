import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/bill_models.dart';
import '../providers/bills_provider.dart';

class BillDialog extends ConsumerStatefulWidget {
  final Bill? existingBill;

  const BillDialog({super.key, this.existingBill});

  @override
  ConsumerState<BillDialog> createState() => _BillDialogState();
}

class _BillDialogState extends ConsumerState<BillDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _dueDate;
  late String _frequency;
  late String _account;

  static const List<(String, String)> _frequencies = [
    ('monthly', 'Monthly'),
    ('weekly', 'Weekly'),
    ('quarterly', 'Quarterly'),
    ('yearly', 'Yearly'),
    ('one_time', 'One-time'),
  ];

  static const List<(String, String, IconData)> _accounts = [
    ('bank', 'Bank', Icons.account_balance_outlined),
    ('bkash', 'bKash', Icons.phone_android),
    ('nagad', 'Nagad', Icons.account_balance_wallet_outlined),
    ('cash', 'Cash', Icons.payments_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    _titleController = TextEditingController(text: bill?.title ?? '');
    _amountController = TextEditingController(
      text: bill != null && bill.amount > 0 ? bill.amount.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: bill?.note ?? '');
    _dueDate = bill?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _frequency = bill?.frequency ?? 'monthly';
    _account = bill?.account ?? 'bank';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existingBill != null;

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Bill' : 'Add Bill / Subscription',
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
                    labelText: 'Bill Title',
                    hintText: 'e.g. Electricity, Netflix, House Rent',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black12 : Colors.grey[100],
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a bill title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount (৳)',
                    prefixIcon: const Icon(Icons.money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black12 : Colors.grey[100],
                  ),
                  validator: (val) {
                    final parsed = double.tryParse(val ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                // Due date picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
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
                            'Due Date: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.edit, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Frequency',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (freqKey, label) in _frequencies)
                      ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: _frequency == freqKey,
                        onSelected: (selected) {
                          if (selected) setState(() => _frequency = freqKey);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pay From Wallet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (accKey, label, icon) in _accounts)
                      ChoiceChip(
                        avatar: Icon(icon, size: 16),
                        label: Text(label, style: const TextStyle(fontSize: 12)),
                        selected: _account == accKey,
                        onSelected: (selected) {
                          if (selected) setState(() => _account = accKey);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'e.g. Account number, meter ID, renewal info',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black12 : Colors.grey[100],
                  ),
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
                  .read(billsListProvider.notifier)
                  .deleteBill(widget.existingBill!.id);
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

            final amount = double.tryParse(_amountController.text) ?? 0.0;
            final title = _titleController.text.trim();
            final note = _noteController.text.trim();

            if (isEditing) {
              await ref.read(billsListProvider.notifier).updateBill(
                widget.existingBill!.id,
                {
                  'title': title,
                  'amount': amount,
                  'due_date':
                      "${_dueDate.year.toString().padLeft(4, '0')}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}",
                  'frequency': _frequency,
                  'account': _account,
                  if (note.isNotEmpty) 'note': note,
                },
              );
            } else {
              await ref.read(billsListProvider.notifier).addBill(
                title: title,
                amount: amount,
                dueDate: _dueDate,
                frequency: _frequency,
                account: _account,
                note: note.isNotEmpty ? note : null,
              );
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isEditing ? 'Bill updated successfully!' : 'Bill added successfully!',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Text(isEditing ? 'Save Changes' : 'Add Bill'),
        ),
      ],
    );
  }
}
