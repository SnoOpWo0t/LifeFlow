import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/sync/sync_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/expense_provider.dart';
import '../../../scan/presentation/scan_sheet.dart';
import 'category_management_dialog.dart'
    show CategoryManagementDialog, categoryColor;
import 'category_budget_dialog.dart';
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
    final isVault = ref.watch(vaultModeProvider);
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
          if (isVault)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Vault Mode Active: Balances concealed',
                child: Icon(Icons.shield, size: 20, color: Color(0xFF10B981)),
              ),
            ),
          IconButton(
            tooltip: 'Scan a receipt or notes',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => startScan(context, target: 'money'),
          ),
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
          Future<void> refresh() => ref.read(syncProvider.notifier).syncNow();

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
            data: (chartData) => _buildBarChart(
              context,
              chartData,
              isDark,
              isVault: isVault,
            ),
          );
          final chart = Column(
            children: [
              barChart,
              if (ref.watch(spendingByCategoryProvider).value
                  case final spending?) ...[
                _buildCategoryBreakdown(
                  context,
                  spending,
                  isDark,
                  isVault: isVault,
                ),
                _buildCategoryBudgetsSection(
                  context,
                  ref,
                  spending,
                  isDark,
                  theme,
                ),
              ],
            ],
          );
          final searchQuery = ref.watch(transactionSearchQueryProvider);
          final typeFilter = ref.watch(transactionTypeFilterProvider);
          final walletFilter = ref.watch(transactionWalletFilterProvider);
          final isFiltering = searchQuery.isNotEmpty ||
              typeFilter != 'all' ||
              walletFilter != 'all';
          final filteredTransactions = ref.watch(filteredTransactionsProvider);

          final transactionSlivers = <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFiltering && transactionsAsync.value != null)
                      Text(
                        '${filteredTransactions.length} of ${transactionsAsync.value!.items.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _TransactionSearchBar(isDark: isDark),
            ),
            SliverToBoxAdapter(
              child: _TransactionFilterChips(isDark: isDark),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 6),
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
                final allTransactions = feed.items;
                if (allTransactions.isEmpty) {
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

                if (filteredTransactions.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No matching transactions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try adjusting your search query or filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Reset Search & Filters'),
                            onPressed: () {
                              ref
                                  .read(transactionSearchQueryProvider.notifier)
                                  .clear();
                              ref
                                  .read(transactionTypeFilterProvider.notifier)
                                  .setFilter('all');
                              ref
                                  .read(transactionWalletFilterProvider.notifier)
                                  .setFilter('all');
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final transactions = filteredTransactions;
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == transactions.length) {
                        return const SizedBox.shrink();
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
                            isVault
                                ? '••••••'
                                : '${isIncome ? '+' : '-'}${formatMoney(tx.amount, decimals: 2)}',
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
    String? selectedCategoryId = existing?.category?.id;
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
                            return DropdownButtonFormField<String>(
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
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.pie_chart_outline, size: 18),
                label: const Text('Configure Category Budgets'),
                onPressed: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (context) => const CategoryBudgetDialog(),
                  );
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
    bool isDark, {
    bool isVault = false,
  }) {
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
                        formatMoney(rod.toY, isVault: isVault),
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
    bool isDark, {
    bool isVault = false,
  }) {
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
                          isVault ? '••••••' : formatMoney(total),
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

  Widget _buildCategoryBudgetsSection(
    BuildContext context,
    WidgetRef ref,
    List<CategorySpending> spending,
    bool isDark,
    ThemeData theme,
  ) {
    final budgets = ref.watch(categoryBudgetsProvider);
    if (budgets.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.pie_chart_outline,
                color: Colors.amber,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Budgets',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Set monthly spending limits for Food, Transport, etc.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const CategoryBudgetDialog(),
                );
              },
              child: const Text('Set Limits'),
            ),
          ],
        ),
      );
    }

    final spendingMap = {
      for (final s in spending) s.name.toLowerCase(): s.total,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Category Budgets',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.tune, size: 20),
                tooltip: 'Edit Budgets',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CategoryBudgetDialog(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final entry in budgets.entries) ...[
            Builder(
              builder: (context) {
                final catName = entry.key;
                final budgetLimit = entry.value;
                final spent = spendingMap[catName.toLowerCase()] ?? 0.0;
                final percent = budgetLimit > 0 ? (spent / budgetLimit) : 0.0;
                final isOver = spent > budgetLimit;
                final isWarning = !isOver && percent >= 0.8;

                final Color progressColor = isOver
                    ? Colors.redAccent
                    : (isWarning ? Colors.amber : const Color(0xFF10B981));

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  catName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isOver) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Exceeded',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ] else if (isWarning) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '80%+ Used',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            ref.watch(vaultModeProvider)
                                ? '•••••• / ••••••'
                                : '${formatMoney(spent)} / ${formatMoney(budgetLimit)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isOver ? Colors.redAccent : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (percent.clamp(0.0, 1.0)).toDouble(),
                          minHeight: 8,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOver
                            ? (ref.watch(vaultModeProvider)
                                ? 'Over budget'
                                : 'Over budget by ${formatMoney(spent - budgetLimit)}')
                            : (ref.watch(vaultModeProvider)
                                ? '${(percent * 100).round()}% spent'
                                : '${formatMoney(budgetLimit - spent)} remaining (${(percent * 100).round()}%)'),
                        style: TextStyle(
                          fontSize: 11,
                          color: isOver ? Colors.redAccent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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

class _TransactionSearchBar extends ConsumerStatefulWidget {
  final bool isDark;
  const _TransactionSearchBar({required this.isDark});

  @override
  ConsumerState<_TransactionSearchBar> createState() =>
      _TransactionSearchBarState();
}

class _TransactionSearchBarState extends ConsumerState<_TransactionSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(transactionSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(transactionSearchQueryProvider);
    if (_controller.text != query) {
      _controller.text = query;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: (val) {
          ref.read(transactionSearchQueryProvider.notifier).setQuery(val);
        },
        decoration: InputDecoration(
          hintText: 'Search note, category, or amount...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    ref.read(transactionSearchQueryProvider.notifier).clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _TransactionFilterChips extends ConsumerWidget {
  final bool isDark;
  const _TransactionFilterChips({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentType = ref.watch(transactionTypeFilterProvider);
    final currentWallet = ref.watch(transactionWalletFilterProvider);

    const walletOptions = [
      (
        key: 'bank',
        label: 'Bank',
        icon: Icons.account_balance,
        color: Color(0xFF60A5FA),
      ),
      (
        key: 'bkash',
        label: 'bKash',
        icon: Icons.phone_android,
        color: Color(0xFFEC4899),
      ),
      (
        key: 'nagad',
        label: 'Nagad',
        icon: Icons.flash_on,
        color: Color(0xFFF59E0B),
      ),
      (
        key: 'cash',
        label: 'Cash',
        icon: Icons.wallet,
        color: Color(0xFF34D399),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          // Type filters
          FilterChip(
            selected: currentType == 'all',
            label: const Text('All Types'),
            onSelected: (_) =>
                ref.read(transactionTypeFilterProvider.notifier).setFilter('all'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: currentType == 'income',
            avatar:
                const Icon(Icons.arrow_downward, size: 14, color: Colors.green),
            label: const Text('Income'),
            onSelected: (_) => ref
                .read(transactionTypeFilterProvider.notifier)
                .setFilter(currentType == 'income' ? 'all' : 'income'),
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: currentType == 'expense',
            avatar:
                const Icon(Icons.arrow_upward, size: 14, color: Colors.redAccent),
            label: const Text('Expense'),
            onSelected: (_) => ref
                .read(transactionTypeFilterProvider.notifier)
                .setFilter(currentType == 'expense' ? 'all' : 'expense'),
          ),
          const SizedBox(width: 12),
          Container(
            height: 20,
            width: 1,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(width: 12),

          // Wallet filters
          FilterChip(
            selected: currentWallet == 'all',
            label: const Text('All Wallets'),
            onSelected: (_) =>
                ref.read(transactionWalletFilterProvider.notifier).setFilter('all'),
          ),
          const SizedBox(width: 6),
          ...walletOptions.map((w) {
            final isSelected = currentWallet == w.key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: isSelected,
                avatar: Icon(w.icon, size: 14, color: w.color),
                label: Text(w.label),
                onSelected: (_) => ref
                    .read(transactionWalletFilterProvider.notifier)
                    .setFilter(isSelected ? 'all' : w.key),
              ),
            );
          }),
        ],
      ),
    );
  }
}
