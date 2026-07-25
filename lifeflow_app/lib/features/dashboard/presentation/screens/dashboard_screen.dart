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
                  final budget = summary.monthlyIncome;
                  final spent = summary.monthlyExpenses;
                  final left = budget - spent;
                  final isOverspent = left < 0;

                  return Container(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Income (Budget)', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('৳ ${budget.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Spent', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('৳ ${spent.toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isOverspent ? 'Overspent' : 'Left', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('৳ ${left.abs().toStringAsFixed(0)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isOverspent ? Colors.redAccent : Colors.green)),
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
                  );
                }),
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
