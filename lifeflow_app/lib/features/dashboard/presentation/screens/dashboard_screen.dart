import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/weather_provider.dart';
import 'dart:ui';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          )
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: ')),
        data: (summary) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(top: 100, left: 16, right: 16, bottom: 24),
              children: [
                Text(
                  'Welcome back,',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                ),
                Text(
                  user?.name ?? 'Guest',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
                
                // Weather Glass Card
                _buildGlassCard(
                  context,
                  isDark: isDark,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud, color: Colors.blueAccent, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('London, UK', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          Text('18°C - Partly Cloudy', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Productivity
                _buildGlassCard(
                  context,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.speed, color: Colors.greenAccent),
                          const SizedBox(width: 8),
                          Text('Productivity Score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${summary.productivityScore}%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: summary.productivityScore / 100,
                          minHeight: 8,
                          backgroundColor: Colors.greenAccent.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Two column layout
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassCard(
                        context,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.purpleAccent, size: 32),
                            const SizedBox(height: 12),
                            Text('Tasks', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${summary.tasksCompleted} / ${summary.tasksTotal} done', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
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
                            const Icon(Icons.repeat, color: Colors.orangeAccent, size: 32),
                            const SizedBox(height: 12),
                            Text('Habits', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${summary.habitsCompleted} / ${summary.habitsTotal} done', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Budget & Expenses Overview
                Builder(builder: (context) {
                  final budget = summary.monthlyBudget > 0 ? summary.monthlyBudget : summary.monthlyIncome;
                  final spent = summary.monthlyExpenses;
                  final left = budget - spent;
                  final isOverspent = left < 0;

                  return Column(
                    children: [
                      if (isOverspent)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Warning: You have exceeded your monthly budget by ৳ ${left.abs().toStringAsFixed(0)}!',
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1E1E2C) : Colors.white),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Budget Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Income', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text('৳ ${summary.monthlyIncome.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(summary.monthlyBudget > 0 ? 'Target Budget' : 'Est. Budget', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text('৳ ${budget.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Spent', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text('৳ ${spent.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isOverspent ? 'Overspent' : 'Remaining', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text('৳ ${left.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isOverspent ? Colors.redAccent : Colors.green)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0,
                            minHeight: 12,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(isOverspent ? Colors.redAccent : (budget > 0 && spent/budget > 0.8 ? Colors.orangeAccent : Colors.greenAccent)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),
                Text('Recent Activity', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (summary.recentActivity.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No recent activity.', style: TextStyle(color: Colors.grey))))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.recentActivity.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = summary.recentActivity[index];
                      final isTask = item.type == 'task';
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1E1E2C) : Colors.white),
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
                              color: isTask 
                                ? Colors.blueAccent.withOpacity(0.2)
                                : (item.isIncome == true ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTask 
                                ? Icons.check_circle_outline
                                : (item.isIncome == true ? Icons.arrow_downward : Icons.arrow_upward),
                              color: isTask 
                                ? Colors.blueAccent
                                : (item.isIncome == true ? Colors.green : Colors.redAccent),
                            ),
                          ),
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${item.date.day}/${item.date.month}/${item.date.year} • ${item.subtitle}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          trailing: isTask || item.amount == null 
                            ? null
                            : Text(
                                '${item.isIncome == true ? '+' : '-'}৳ ${item.amount!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: item.isIncome == true ? Colors.green : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
