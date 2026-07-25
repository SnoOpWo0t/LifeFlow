import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/expense_provider.dart';
import 'category_management_dialog.dart';
import '../../domain/expense_models.dart';

class ExpenseScreen extends ConsumerWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final chartDataAsync = ref.watch(chartDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const CategoryManagementDialog(),
              );
            },
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: chartDataAsync.when(
              loading: () => const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => SizedBox(height: 250, child: Center(child: Text('Error: $err'))),
              data: (chartData) => _buildBarChart(context, chartData, isDark),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Text('Recent Transactions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          transactionsAsync.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.grey))));
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = transactions[index];
                      final isIncome = tx.type == 'income';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isIncome ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.redAccent,
                            ),
                          ),
                          title: Text(tx.note ?? tx.category?.name ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${tx.transactionDate.day}/${tx.transactionDate.month}/${tx.transactionDate.year} â€¢ ${tx.category?.name ?? "General"}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}৳ ${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isIncome ? Colors.green : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: transactions.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for FAB
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context, ref, theme),
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, ThemeData theme) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    int? selectedCategoryId;
    String type = 'expense';
    DateTime selectedDate = DateTime.now();

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text('New Transaction', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'expense', label: Text('Expense')),
                            ButtonSegment(value: 'income', label: Text('Income')),
                          ],
                          selected: {type},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() => type = newSelection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount (৳)',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          decoration: InputDecoration(
                            labelText: 'Note (optional)',
                            prefixIcon: const Icon(Icons.note),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 12),
                        categoriesAsync.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (e, s) => Text('Error loading categories', style: TextStyle(color: theme.colorScheme.error)),
                          data: (categories) {
                            return DropdownButtonFormField<int>(
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: const Icon(Icons.category),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[100],
                              ),
                              value: selectedCategoryId,
                              items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                              onChanged: (val) {
                                setState(() => selectedCategoryId = val);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: theme.brightness == Brightness.dark ? Colors.black12 : Colors.grey[100],
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Transaction Date'),
                          subtitle: Text('//'),
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
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (amountController.text.isNotEmpty) {
                          ref.read(expenseRepositoryProvider).addTransaction({
                            'amount': double.parse(amountController.text),
                            'note': noteController.text,
                            'type': type,
                            if (selectedCategoryId != null) 'category_id': selectedCategoryId,
                            'transaction_date': selectedDate.toIso8601String(),
                          }).then((_) {
                            ref.invalidate(transactionsProvider);
                            ref.invalidate(chartDataProvider);
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              }
            );
          }
        );
      }
    );
  }

  Widget _buildDonutChart(BuildContext context, List<Transaction> transactions, bool isDark, ThemeData theme) {
    final expenses = transactions.where((t) => t.type == 'expense').toList();
    if (expenses.isEmpty) return const SizedBox.shrink();

    final categoryTotals = <String, double>{};
    final categoryColors = <String, Color>{};

    for (var tx in expenses) {
      final catName = tx.category?.name ?? 'General';
      categoryTotals[catName] = (categoryTotals[catName] ?? 0) + tx.amount;
      if (tx.category?.colorHex != null && !categoryColors.containsKey(catName)) {
        categoryColors[catName] = Color(int.parse(tx.category!.colorHex!.replaceFirst('#', '0xff')));
      }
    }

    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final List<PieChartSectionData> sections = [];
    int i = 0;
    final defaultColors = [Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent, Colors.tealAccent];
    
    categoryTotals.forEach((name, total) {
      final color = categoryColors[name] ?? defaultColors[i % defaultColors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: total,
          title: '${((total / expenses.fold(0.0, (sum, item) => sum + item.amount)) * 100).toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
      i++;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Category-wise spending', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...categoryTotals.entries.map((e) {
            final color = categoryColors[e.key] ?? defaultColors[categoryTotals.keys.toList().indexOf(e.key) % defaultColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: color.withOpacity(0.2), radius: 12, child: Icon(Icons.circle, size: 12, color: color)),
                  const SizedBox(width: 12),
                  Text(e.key, style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Text('৳ ${e.value.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<Map<String, dynamic>> data, bool isDark) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('No chart data', style: TextStyle(color: Colors.grey))));

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
            BarChartRodData(toY: inc, color: Colors.greenAccent, width: 8, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: exp, color: Colors.redAccent, width: 8, borderRadius: BorderRadius.circular(4)),
          ],
        )
      );
      x++;
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => isDark ? Colors.white : Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '৳ ${rod.toY.toStringAsFixed(0)}',
                  TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8), 
                      child: Text(sortedDates[value.toInt()], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}
