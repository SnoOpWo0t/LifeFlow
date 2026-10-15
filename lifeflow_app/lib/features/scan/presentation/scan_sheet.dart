import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/formatters.dart';
import '../../analytics/presentation/providers/analytics_provider.dart';
import '../../calendar/presentation/providers/calendar_provider.dart';
import '../../calendar/domain/calendar_models.dart' show dateKey;
import '../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../expenses/domain/expense_models.dart';
import '../../expenses/presentation/providers/expense_provider.dart';
import '../../wishlist/presentation/providers/wishlist_provider.dart';
import '../data/scan_repository.dart';
import '../domain/scan_result.dart';

/// Colours for categories a scan creates.
const _newCategoryColors = [
  '#F97316',
  '#22C55E',
  '#3B82F6',
  '#8B5CF6',
  '#EC4899',
  '#14B8A6',
  '#EAB308',
  '#EF4444',
];

const _accounts = [
  (value: 'cash', label: 'Cash'),
  (value: 'bkash', label: 'bKash'),
  (value: 'nagad', label: 'Nagad'),
  (value: 'bank', label: 'Bank'),
];

/// Scan a photo into entries: asks camera or gallery, then shows the review
/// sheet. [target]: 'money' (receipts and notes) or 'wishlist'.
Future<void> startScan(BuildContext context, {required String target}) async {
  final wishlist = target == 'wishlist';
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wishlist ? 'Scan a shopping list' : 'Scan a receipt or notes',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              wishlist
                  ? 'A list in your notes, a chat, handwriting, or screenshots of products. You check everything before it\'s added.'
                  : 'A shop receipt or memo, or a screenshot of notes where you wrote down expenses and income. You check everything before it\'s saved.',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo or screenshot'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? file;
  try {
    // The reader only needs ~1600px; smaller uploads are faster and cheaper.
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? "Couldn't open the camera. Choose a photo instead."
                : "Couldn't open your photos.",
          ),
        ),
      );
    }
    return;
  }
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (_) => ScanReviewSheet(bytes: bytes, target: target),
  );
}

/// One editable line in the review list.
class _Line {
  _Line({
    required this.type,
    required String name,
    required double amount,
    required this.category,
    this.date = '',
    this.priority = 'normal',
    this.note = '',
    this.link = '',
    this.isExtra = false,
  }) : name = TextEditingController(text: name),
       amount = TextEditingController(text: amount == 0 ? '' : _plain(amount));

  String type; // expense | income | wish
  final TextEditingController name;
  final TextEditingController amount;
  String category;
  String date;
  String priority;
  final String note;
  final String link;
  final bool isExtra;
  bool selected = true;

  double get value =>
      double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class ScanReviewSheet extends ConsumerStatefulWidget {
  const ScanReviewSheet({super.key, required this.bytes, required this.target});

  final List<int> bytes;
  final String target;

  @override
  ConsumerState<ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends ConsumerState<ScanReviewSheet> {
  ScanResult? _result;
  String? _error;
  bool _saving = false;

  final _lines = <_Line>[];
  late DateTime _date;
  String _account = 'cash';
  bool _combine = false; // receipts: one expense for the whole receipt
  double _discount = 0;
  String _merchant = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _read();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _read() async {
    setState(() {
      _error = null;
      _result = null;
    });
    try {
      final result = await ref
          .read(scanRepositoryProvider)
          .scan(widget.bytes, widget.target);
      if (!mounted) return;
      _lines.clear();
      switch (result) {
        case ScannedReceipt r:
          _merchant = r.merchant;
          _discount = r.discount;
          if (r.date.isNotEmpty) _date = DateTime.parse(r.date);
          final mostCommon = _mostCommonCategory(r.items);
          for (final i in r.items) {
            _lines.add(
              _Line(
                type: 'expense',
                name: i.name,
                amount: i.amount,
                category: i.category,
              ),
            );
          }
          for (final x in r.extras) {
            // VAT, delivery… go with the receipt's main category.
            _lines.add(
              _Line(
                type: 'expense',
                name: x.name,
                amount: x.amount,
                category: mostCommon,
                isExtra: true,
              ),
            );
          }
        case ScannedNotes n:
          if (n.date.isNotEmpty) _date = DateTime.parse(n.date);
          for (final e in n.entries) {
            _lines.add(
              _Line(
                type: e.type,
                name: e.name,
                amount: e.amount,
                category: e.category,
                date: e.date,
              ),
            );
          }
        case ScannedWishlist w:
          for (final i in w.items) {
            _lines.add(
              _Line(
                type: 'wish',
                name: i.title,
                amount: i.price,
                category: i.category,
                priority: i.priority,
                note: i.note,
                link: i.link,
              ),
            );
          }
      }
      setState(() => _result = result);
    } on ScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Something went wrong reading this photo. Try again.',
        );
      }
    }
  }

  String _mostCommonCategory(List<ScannedLine> items) {
    final counts = <String, double>{};
    for (final i in items.where((i) => i.category.isNotEmpty)) {
      counts[i.category] = (counts[i.category] ?? 0) + i.amount;
    }
    if (counts.isEmpty) return '';
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  List<_Line> get _selected =>
      _lines.where((l) => l.selected && l.value > 0).toList();

  /// Discount share per selected line (receipt items only, not extras).
  Map<_Line, double> _shares() {
    final items = _selected.where((l) => !l.isExtra).toList();
    final shares = discountShares([for (final l in items) l.value], _discount);
    return {for (var i = 0; i < items.length; i++) items[i]: shares[i]};
  }

  double get _selectedTotal {
    final sum = _selected.fold<double>(
      0,
      (a, l) => a + (l.type == 'income' ? 0 : l.value),
    );
    return _result is ScannedReceipt
        ? (sum - _discount).clamp(0, double.infinity)
        : sum;
  }

  // ------------------------------------------------------------------ saving

  Future<void> _save() async {
    final lines = _selected;
    if (lines.isEmpty) return;
    setState(() => _saving = true);
    try {
      if (_result is ScannedWishlist) {
        await _saveWishlist(lines);
      } else {
        await _saveMoney(lines);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't save everything. Check your connection and try again.",
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveWishlist(List<_Line> lines) async {
    final notifier = ref.read(wishlistProvider.notifier);
    for (final l in lines) {
      await notifier.addItem({
        'title': l.name.text.trim().isEmpty ? 'Item' : l.name.text.trim(),
        if (l.note.isNotEmpty) 'note': l.note,
        if (l.value > 0) 'estimated_price': l.value,
        'priority': l.priority,
        if (l.category.isNotEmpty) 'category': l.category,
        if (l.link.isNotEmpty) 'link': l.link,
      });
    }
    _done(
      'Added ${lines.length} ${lines.length == 1 ? 'item' : 'items'} to your wishlist.',
    );
  }

  Future<void> _saveMoney(List<_Line> lines) async {
    final repo = ref.read(expenseRepositoryProvider);
    final existing = await ref.read(categoriesProvider.future);
    final ids = <String, int>{
      for (final c in existing) '${c.type}:${c.name.toLowerCase()}': c.id,
    };
    final created = <String>[];

    Future<int?> categoryId(String type, String name) async {
      if (name.isEmpty) return null;
      final key = '$type:${name.toLowerCase()}';
      if (ids.containsKey(key)) return ids[key];
      final category = await repo.createCategory({
        'name': name,
        'type': type,
        'color_hex':
            _newCategoryColors[(existing.length + created.length) %
                _newCategoryColors.length],
      });
      created.add(name);
      return ids[key] = category.id;
    }

    String dateOf(_Line l) => l.date.isNotEmpty ? l.date : dateKey(_date);
    var saved = 0;

    if (_result is ScannedReceipt && _combine) {
      // One expense for the whole receipt, in its main category.
      final main =
          lines
              .where((l) => !l.isExtra)
              .fold<_Line?>(
                null,
                (best, l) => best == null || l.value > best.value ? l : best,
              ) ??
          lines.first;
      await repo.addTransaction({
        'amount': double.parse(_selectedTotal.toStringAsFixed(2)),
        'type': 'expense',
        'category_id': await categoryId('expense', main.category),
        'transaction_date': dateKey(_date),
        'note': _merchant.isNotEmpty
            ? _merchant
            : 'Receipt (${lines.length} items)',
        'account': _account,
      });
      saved = 1;
    } else {
      final shares = _result is ScannedReceipt
          ? _shares()
          : const <_Line, double>{};
      for (final l in lines) {
        final amount = l.value - (shares[l] ?? 0);
        if (amount <= 0) continue;
        await repo.addTransaction({
          'amount': double.parse(amount.toStringAsFixed(2)),
          'type': l.type,
          'category_id': await categoryId(l.type, l.category),
          'transaction_date': dateOf(l),
          'note': [
            if (_merchant.isNotEmpty) _merchant,
            l.name.text.trim(),
          ].where((s) => s.isNotEmpty).join(' · '),
          'account': _account,
        });
        saved++;
      }
    }

    ref.invalidate(transactionsProvider);
    ref.invalidate(chartDataProvider);
    ref.invalidate(spendingByCategoryProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(weeklyAnalyticsProvider);
    ref.invalidate(calendarMonthProvider);
    ref.invalidate(calendarDayProvider);

    _done(
      'Added $saved ${saved == 1 ? 'transaction' : 'transactions'}'
      '${created.isEmpty ? '' : '. New ${created.length == 1 ? 'category' : 'categories'}: ${created.join(', ')}'}.',
    );
  }

  void _done(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = _error != null
        ? _buildError(theme)
        : _result == null
        ? _buildReading(theme)
        : _buildReview(theme);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: body,
      ),
    );
  }

  Widget _buildReading(ThemeData theme) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Reading your photo…',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'This can take up to a minute.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildError(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _read,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildReview(ThemeData theme) {
    final result = _result!;
    final isReceipt = result is ScannedReceipt;
    final isWishlist = result is ScannedWishlist;
    final categoriesAsync = isWishlist ? null : ref.watch(categoriesProvider);
    final categories = categoriesAsync?.value ?? const <ExpenseCategory>[];
    final selectedCount = _selected.length;

    final title = switch (result) {
      ScannedReceipt() =>
        _merchant.isNotEmpty ? 'Receipt: $_merchant' : 'Receipt',
      ScannedNotes() => 'From your notes',
      ScannedWishlist() => 'Shopping list',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Check what was found: untick anything wrong, fix names, amounts and categories, then save.',
                style: TextStyle(color: Colors.grey),
              ),
              if (!isWishlist) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.event_outlined, size: 18),
                      label: Text(dateKey(_date)),
                      tooltip: 'Date for lines without their own date',
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                    ),
                    DropdownButton<String>(
                      value: _account,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        for (final a in _accounts)
                          DropdownMenuItem(
                            value: a.value,
                            child: Text('Paid from ${a.label}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _account = v ?? 'cash'),
                    ),
                    if (isReceipt)
                      FilterChip(
                        label: const Text('Save as one expense'),
                        selected: _combine,
                        onSelected: (v) => setState(() => _combine = v),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: _lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _buildLine(theme, _lines[i], categories, isWishlist),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$selectedCount of ${_lines.length} selected',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (!isWishlist)
                      Text(
                        isReceipt
                            ? 'Total ${formatMoney(_selectedTotal, decimals: 2)}'
                                  '${_discount > 0 ? ' (after ${formatMoney(_discount, decimals: 2)} discount)' : ''}'
                            : 'Spent ${formatMoney(_selectedTotal, decimals: 2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _saving || selectedCount == 0 ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(isWishlist ? 'Add to wishlist' : 'Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLine(
    ThemeData theme,
    _Line line,
    List<ExpenseCategory> categories,
    bool isWishlist,
  ) {
    final isIncome = line.type == 'income';
    final names = isWishlist
        ? <String>[]
        : categories
              .where((c) => c.type == line.type)
              .map((c) => c.name)
              .toList();
    final isNew =
        !isWishlist &&
        line.category.isNotEmpty &&
        !names.any((n) => n.toLowerCase() == line.category.toLowerCase());

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: line.selected ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: line.selected,
              onChanged: (v) => setState(() => line.selected = v ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: line.name,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Name',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: 104,
                        child: TextField(
                          controller: line.amount,
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            prefixText: isIncome ? '+৳ ' : '৳ ',
                            hintText: isWishlist ? 'Price' : '0',
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncome ? Colors.green : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_result is ScannedNotes)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 16,
                            color: isIncome ? Colors.green : Colors.redAccent,
                          ),
                          label: Text(isIncome ? 'Income' : 'Expense'),
                          tooltip: 'Switch between expense and income',
                          onPressed: () => setState(() {
                            line.type = isIncome ? 'expense' : 'income';
                          }),
                        ),
                      if (!isWishlist)
                        PopupMenuButton<String>(
                          tooltip: 'Change category',
                          onSelected: (v) => setState(
                            () => line.category = v == '\u0000' ? '' : v,
                          ),
                          itemBuilder: (_) => [
                            for (final n in names)
                              PopupMenuItem(value: n, child: Text(n)),
                            if (isNew)
                              PopupMenuItem(
                                value: line.category,
                                child: Text('${line.category} (new)'),
                              ),
                            const PopupMenuItem(
                              value: '\u0000',
                              child: Text('No category'),
                            ),
                          ],
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                              isNew
                                  ? Icons.add_circle_outline
                                  : Icons.label_outline,
                              size: 16,
                            ),
                            label: Text(
                              line.category.isEmpty
                                  ? 'No category'
                                  : isNew
                                  ? '${line.category} (new)'
                                  : line.category,
                            ),
                          ),
                        )
                      else ...[
                        if (line.category.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(line.category),
                          ),
                        PopupMenuButton<String>(
                          tooltip: 'Priority',
                          onSelected: (v) => setState(() => line.priority = v),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'high', child: Text('High')),
                            PopupMenuItem(
                              value: 'normal',
                              child: Text('Normal'),
                            ),
                            PopupMenuItem(value: 'low', child: Text('Low')),
                          ],
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              '${line.priority[0].toUpperCase()}${line.priority.substring(1)} priority',
                            ),
                          ),
                        ),
                      ],
                      if (line.isExtra)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Extra charge'),
                        ),
                      if (line.date.isNotEmpty)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.event_outlined, size: 16),
                          label: Text(line.date),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
