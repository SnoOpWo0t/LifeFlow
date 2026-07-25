import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../../domain/analytics_models.dart';
import 'dart:math';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(weeklyAnalyticsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weeklyAnalyticsProvider);
        },
        child: analyticsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => ListView(
            children: [
               SizedBox(height: MediaQuery.of(context).size.height * 0.4),
               Center(child: Text('Error: $err')),
            ],
          ),
          data: (analytics) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSummaryCards(context, analytics, isDark, theme),
                      const SizedBox(height: 24),
                      _buildFinancialChart(context, analytics, isDark, theme),
                      const SizedBox(height: 24),
                      _buildProductivityChart(context, analytics, isDark, theme),
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, WeeklyAnalytics analytics, bool isDark, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            context,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.savings, color: Colors.greenAccent, size: 28),
                const SizedBox(height: 12),
                Text('Weekly Savings', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '${analytics.totalSavings >= 0 ? '+' : '-'}৳ ${analytics.totalSavings.abs().toStringAsFixed(0)}',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: analytics.totalSavings >= 0 ? Colors.green : Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassCard(
            context,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 28),
                const SizedBox(height: 12),
                Text('Best Day', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  analytics.mostProductiveDay,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialChart(BuildContext context, WeeklyAnalytics analytics, bool isDark, ThemeData theme) {
    double maxVal = 0;
    for (var day in analytics.weeklyData) {
      if (day.income > maxVal) maxVal = day.income;
      if (day.expenses > maxVal) maxVal = day.expenses;
    }
    if (maxVal == 0) maxVal = 1000;

    return _buildGlassCard(
      context,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Income vs Expenses', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal / 4 > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= analytics.weeklyData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(analytics.weeklyData[index].dayName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxVal / 4 > 0 ? maxVal / 4 : 1,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        String text = value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0);
                        return Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxVal * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: analytics.weeklyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.income)).toList(),
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.greenAccent.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: analytics.weeklyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expenses)).toList(),
                    isCurved: true,
                    color: Colors.redAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.redAccent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.greenAccent, 'Income'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.redAccent, 'Expenses'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProductivityChart(BuildContext context, WeeklyAnalytics analytics, bool isDark, ThemeData theme) {
    double maxVal = 0;
    for (var day in analytics.weeklyData) {
      if (day.productivityScore > maxVal) maxVal = day.productivityScore.toDouble();
    }
    if (maxVal == 0) maxVal = 5;

    return _buildGlassCard(
      context,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Productivity Score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= analytics.weeklyData.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(analytics.weeklyData[index].dayName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: max(1.0, (maxVal / 4).roundToDouble()),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: max(1.0, (maxVal / 4).roundToDouble()),
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: analytics.weeklyData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.tasksCompleted.toDouble(),
                        color: Colors.purpleAccent,
                        width: 12,
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.zero, bottomRight: Radius.zero, topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: e.value.habitsCompleted.toDouble(),
                        color: Colors.orangeAccent,
                        width: 12,
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.zero, bottomRight: Radius.zero, topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.purpleAccent, 'Tasks'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orangeAccent, 'Habits'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E2C) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}
