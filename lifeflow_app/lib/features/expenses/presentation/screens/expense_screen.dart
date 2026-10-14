import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/expense_provider.dart';
import 'category_management_dialog.dart'
    show CategoryManagementDialog, categoryColor;
import '../../domain/expense_models.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../main_screen.dart';

class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final chartDataAsync = ref.watch(chartDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Set monthly budget',
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => _showSetBudgetDialog(context, ref, theme),
          ),
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CategoryManagementDialog(),
              );
            },
          ),
          IconButton(
            tooltip: 'Wishlist',
            icon: const Icon(Icons.card_giftcard),
            onPressed: () {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.wishlist);
            },
          ),
          if (isWide)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: FilledButton.icon(
                onPressed: () => _showTransactionDialog(context, ref, theme),
                icon: const Icon(Icons.add),
                label: const Text('Add transaction'),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          Future<void> refresh() async {
            ref.invalidate(transactionsProvider);
            ref.invalidate(chartDataProvider);
            ref.invalidate(spendingByCategoryProvider);
            await ref.read(transactionsProvider.future);
          }

          // Infinite scroll: fetch the next page shortly before the end.
          bool onScroll(ScrollNotification notification) {
            if (notification.metrics.extentAfter < 600) {
              ref.read(transactionsProvider.notifier).loadMore();
            }
            return false;
          }

          final barChart = chartDataAsync.when(
            loading: () => const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => const SizedBox(
              height: 250,
              child: Center(child: Text("Couldn't load the chart.")),
            ),
            data: (chartData) => _buildBarChart(context, chartData, isDark),
          );
          final chart = Column(
            children: [
              barChart,
              if (ref.watch(spendingByCategoryProvider).value
                  case final spending?)
                _buildCategoryBreakdown(context, spending, isDark),
            ],
          );
          final transactionSlivers = <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            transactionsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(transactionsProvider),
                    child: const Text(
                      "Couldn't load transactions. Tap to retry.",
                    ),
                  ),
                ),
              ),
              data: (feed) {
                final transactions = feed.items;
                if (transactions.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No transactions yet',
                      message:
                          'Add your income and spending to see where your money goes.',
                      actionLabel: 'Add transaction',
                      onAction: () =>
                          _showTransactionDialog(context, ref, theme),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == transactions.length) {
                        // Next page is on its way.
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final tx = transactions[index];
                      final isIncome = tx.type == 'income';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.03,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          // Tap to edit; delete lives inside the edit dialog.
                          onTap: () => _showTransactionDialog(
                            context,
                            ref,
                            theme,
                            existing: tx,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isIncome
                                  ? Colors.greenAccent.withValues(alpha: 0.2)
                                  : Colors.redAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isIncome
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            tx.note ?? tx.category?.name ?? 'Transaction',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${tx.transactionDate.day}/${tx.transactionDate.month}/${tx.transactionDate.year} • ${tx.category?.name ?? "General"}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}${formatMoney(tx.amount, decimals: 2)}',
                            style: TextStyle(
                              color: isIncome ? Colors.green : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }, childCount: transactions.length + (feed.hasMore ? 1 : 0)),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: isWide ? 24 : 100),
            ), // Room for the FAB on phones
          ];

          // Desktop: chart beside the list instead of above it.
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: SingleChildScrollView(child: chart)),
                Expanded(
                  flex: 6,
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: onScroll,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          ...transactionSlivers,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: onScroll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: chart),
                  ...transactionSlivers,
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showTransactionDialog(context, ref, theme),
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  /// Add a transaction, or edit/delete [existing] when given.
  void _showTransactionDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme, {
    Transaction? existing,
  }) {
    final amountController = TextEditingController(
      text: existing == null
          ? ''
          : existing.amount.toStringAsFixed(existing.amount % 1 == 0 ? 0 : 2),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    int? selectedCategoryId = existing?.category?.id;
    String type = existing?.type ?? 'expense';
    String selectedAccount = existing?.account ?? 'cash';
    DateTime selectedDate = existing?.transactionDate ?? DateTime.now();
    String? amountError;

    void refreshMoneyViews() {
      ref.invalidate(transactionsProvider);
      ref.invalidate(chartDataProvider);
      ref.invalidate(spendingByCategoryProvider);
      ref.invalidate(dashboardSummaryProvider);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer(
              builder: (context, ref, child) {
                final categoriesAsync = ref.watch(categoriesProvider);

                return AlertDialog(
                  backgroundColor: theme.cardTheme.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Text(
                    existing == null ? 'New Transaction' : 'Edit Transaction',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'expense',
                              label: Text('Expense'),
                            ),
                            ButtonSegment(
                              value: 'income',
                              label: Text('Income'),
                            ),
                          ],
                          selected: {type},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() => type = newSelection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Amount (৳)',
                            errorText: amountError,
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.brightness == Brightness.dark
                                ? Colors.black12
                                : Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          decoration: InputDecoration(
                            labelText: 'Note (optional)',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.brightness == Brightness.dark
                                ? Colors.black12
                                : Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Account selector
                        _buildAccountPicker(
                          theme: theme,
                          selectedAccount: selectedAccount,
                          onChanged: (val) =>
                              setState(() => selectedAccount = val),
                        ),
                        const SizedBox(height: 12),
                        categoriesAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (e, s) => Text(
                            'Error loading categories',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          data: (categories) {
                            return DropdownButtonFormField<int>(
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: const Icon(Icons.category),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.brightness == Brightness.dark
                                    ? Colors.black12
                                    : Colors.grey[100],
                              ),
                              initialValue: selectedCategoryId,
                              items: categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() => selectedCategoryId = val);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: theme.brightness == Brightness.dark
                              ? Colors.black12
                              : Colors.grey[100],
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Transaction Date'),
                          subtitle: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (existing != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete transaction?'),
                              content: Text(
                                '"${existing.note ?? existing.category?.name ?? 'Transaction'}" will be permanently removed.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          await ref
                              .read(expenseRepositoryProvider)
                              .deleteTransaction(existing.id);
                          refreshMoneyViews();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Delete'),
                      ),
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
                      onPressed: () async {
                        // Accept "1,500" as well as "1500"; reject anything else
                        // instead of throwing (double.parse used to crash here).
                        final amount = double.tryParse(
                          amountController.text.replaceAll(',', '').trim(),
                        );
                        if (amount == null || amount <= 0) {
                          setState(
                            () =>
                                amountError = 'Enter an amount greater than 0',
                          );
                          return;
                        }
                        final data = {
                          'amount': amount,
                          'note': noteController.text,
                          'type': type,
                          'account': selectedAccount,
                          'category_id': selectedCategoryId,
                          'transaction_date': selectedDate.toIso8601String(),
                        };
                        final repo = ref.read(expenseRepositoryProvider);
                        Navigator.pop(ctx);
                        if (existing == null) {
                          await repo.addTransaction(data);
                        } else {
                          await repo.updateTransaction(existing.id, data);
                        }
                        refreshMoneyViews();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSetBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final currentBudget = ref.read(settingsRepositoryProvider).monthlyBudget;
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Set Monthly Budget',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your target monthly budget limit. Leave blank or 0 to dynamically use your total monthly income.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (৳)',
                  prefixIcon: const Icon(Icons.money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? Colors.black12
                      : Colors.grey[100],
                ),
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
              onPressed: () async {
                final amount = double.tryParse(controller.text) ?? 0.0;
                await ref
                    .read(settingsRepositoryProvider)
                    .saveSettings(monthlyBudget: amount);
                ref.invalidate(
                  dashboardSummaryProvider,
                ); // Refresh dashboard with new budget
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _shortDate(String monthDay) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final parts = monthDay.split('-');
    final month = int.tryParse(parts[0]) ?? 0;
    final day = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    if (month < 1 || month > 12 || day == 0) return monthDay;
    return '$day ${months[month - 1]}';
  }

  Widget _buildBarChart(
    BuildContext context,
    List<Map<String, dynamic>> data,
    bool isDark,
  ) {
    if (data.isEmpty)
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('No chart data', style: TextStyle(color: Colors.grey)),
        ),
      );

    double maxVal = 1000;

    // Group data by date
    final groupedData = <String, Map<String, double>>{};
    for (var row in data) {
      final date = row['transaction_date'].toString().substring(5, 10); // MM-DD
      final type = row['type'] as String;
      final total = double.tryParse(row['total'].toString()) ?? 0.0;

      if (total > maxVal) maxVal = total;

      if (!groupedData.containsKey(date)) {
        groupedData[date] = {'income': 0, 'expense': 0};
      }
      groupedData[date]![type] = groupedData[date]![type]! + total;
    }

    final sortedDates = groupedData.keys.toList()..sort();
    List<BarChartGroupData> barGroups = [];
    int x = 0;

    for (var date in sortedDates) {
      final inc = groupedData[date]!['income']!;
      final exp = groupedData[date]!['expense']!;
      barGroups.add(
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: inc,
              color: Colors.greenAccent,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: exp,
              color: Colors.redAccent,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      x++;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Income vs Expense',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  _buildLegendItem(Colors.greenAccent, 'Income', isDark),
                  const SizedBox(width: 12),
                  _buildLegendItem(Colors.redAccent, 'Expense', isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) =>
                        isDark ? Colors.white : Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        formatMoney(rod.toY),
                        TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        // Skip 0 and the padded top value, which collided with the label below it.
                        if (value == 0 || value == meta.max)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
                                : value.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < sortedDates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _shortDate(sortedDates[value.toInt()]),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Donut of this month's spending per category (the largest five, plus "Other").
  Widget _buildCategoryBreakdown(
    BuildContext context,
    List<CategorySpending> spending,
    bool isDark,
  ) {
    if (spending.isEmpty) return const SizedBox.shrink();

    // The server returns categories largest first; keep five, group the rest.
    final slices = [
      for (final c in spending.take(5))
        MapEntry(c.name, (
          amount: c.total,
          color: c.name == 'Uncategorised'
              ? Colors.blueGrey
              : categoryColor(c.colorHex),
        )),
    ];
    final otherTotal = spending
        .skip(5)
        .fold<double>(0, (sum, c) => sum + c.total);
    if (otherTotal > 0) {
      slices.add(MapEntry('Other', (amount: otherTotal, color: Colors.grey)));
    }
    final total = slices.fold<double>(0, (sum, e) => sum + e.value.amount);
    // Categories saved before colours worked are grey; give those distinct hues.
    const fallbackHues = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    var fallback = 0;
    final colored = [
      for (final e in slices)
        (
          name: e.key,
          amount: e.value.amount,
          color: e.value.color == Colors.grey && e.key != 'Other'
              ? fallbackHues[fallback++ % fallbackHues.length]
              : e.value.color,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by category (this month)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 44,
                        sections: [
                          for (final slice in colored)
                            PieChartSectionData(
                              value: slice.amount,
                              color: slice.color,
                              radius: 22,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          formatMoney(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final slice in colored)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: slice.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                slice.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(slice.amount / total * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

/// Styled helper that lets the user pick which wallet (account) a transaction belongs to.
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
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'Account',
            style: theme.textTheme.bodyMedium?.copyWith(
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
                    vertical: 8,
                    horizontal: 4,
                  ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        opt.icon,
                        size: 18,
                        color: isSelected ? color : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 11,
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

/// Friendly placeholder for an empty list, with one obvious next step.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
