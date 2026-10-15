import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/savings_models.dart';
import '../../domain/savings_goal_models.dart';
import '../providers/savings_provider.dart';
import '../providers/savings_goals_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../widgets/savings_dialog.dart';
import '../widgets/savings_goal_dialog.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  void _openDepositDialog(BuildContext context, {String? account}) {
    showDialog(
      context: context,
      builder: (ctx) => SavingsDialog(
        defaultType: 'deposit',
        defaultAccount: account,
      ),
    );
  }

  void _openWithdrawDialog(BuildContext context, {String? account}) {
    showDialog(
      context: context,
      builder: (ctx) => SavingsDialog(
        defaultType: 'withdrawal',
        defaultAccount: account,
      ),
    );
  }

  void _editSaving(BuildContext context, Saving saving) {
    showDialog(
      context: context,
      builder: (ctx) => SavingsDialog(initialSaving: saving),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summary = ref.watch(savingsSummaryProvider);
    final filteredSavings = ref.watch(filteredSavingsProvider);
    final activeAccountFilter = ref.watch(savingsAccountFilterProvider);
    final activeTypeFilter = ref.watch(savingsTypeFilterProvider);
    final isVault = ref.watch(vaultModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.savings, color: Color(0xFF10B981), size: 26),
            SizedBox(width: 10),
            Text(
              'Savings Vault',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
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
            tooltip: 'Withdraw',
            icon: const Icon(Icons.outbox_outlined, color: Color(0xFFEF4444)),
            onPressed: () => _openWithdrawDialog(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Deposit',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _openDepositDialog(context),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savingsListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total Savings Banner Card
            _buildTotalSavingsCard(context, summary, isDark, isVault),
            const SizedBox(height: 16),

            // Per-Wallet Breakdown (Bank, bKash, Nagad, Cash)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved by Wallet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Separate from expenses',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWalletsGrid(context, ref, summary, activeAccountFilter, isDark, isVault),
            const SizedBox(height: 24),

            // Savings Goals Section (Customizable / Toggleable)
            _buildSavingsGoalsSection(context, ref, isDark, theme),
            const SizedBox(height: 24),

            // Filter Chips
            _buildFilterChips(
              context,
              ref,
              activeAccountFilter,
              activeTypeFilter,
              isDark,
            ),
            const SizedBox(height: 16),

            // Transaction History Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Savings History',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${filteredSavings.length} records',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of Transactions or Empty State
            if (filteredSavings.isEmpty)
              _buildEmptyState(context, isDark)
            else
              ...filteredSavings.map((saving) => _buildSavingTile(
                    context,
                    saving,
                    isDark,
                    isVault,
                  )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSavingsCard(
    BuildContext context,
    SavingsSummary summary,
    bool isDark,
    bool isVault,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF064E3B), // Dark emerald
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFF10B981), // Emerald
                  const Color(0xFF059669),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'TOTAL SAVINGS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Reserved Fund',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isVault ? '৳ ••••••' : '৳ ${summary.totalSavings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_downward,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Deposits',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          isVault ? '••••••' : '৳ ${summary.totalDeposits.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Withdrawals',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          isVault ? '••••••' : '৳ ${summary.totalWithdrawals.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  Widget _buildWalletsGrid(
    BuildContext context,
    WidgetRef ref,
    SavingsSummary summary,
    String activeFilter,
    bool isDark,
    bool isVault,
  ) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 500;
      final crossAxisCount = isWide ? 4 : 2;

      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isWide ? 1.4 : 1.35,
        children: SavingsAccountMeta.accounts.map((acc) {
          final balance = summary.byAccount[acc.key] ?? 0.0;
          final isSelected = activeFilter.toLowerCase() == acc.key.toLowerCase();

          return InkWell(
            onTap: () {
              // Toggle filter
              final newFilter = isSelected ? 'all' : acc.key;
              ref
                  .read(savingsAccountFilterProvider.notifier)
                  .setFilter(newFilter);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark
                    ? (isSelected
                        ? acc.color.withValues(alpha: 0.2)
                        : const Color(0xFF1E293B))
                    : (isSelected
                        ? acc.color.withValues(alpha: 0.12)
                        : Colors.white),
                border: Border.all(
                  color: isSelected
                      ? acc.color
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: acc.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(acc.icon, color: acc.color, size: 18),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: acc.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'FILTERED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVault ? '••••••' : '৳ ${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: balance < 0
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    String activeAccount,
    String activeType,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All Wallets
          FilterChip(
            selected: activeAccount == 'all',
            label: const Text('All Wallets'),
            onSelected: (_) => ref
                .read(savingsAccountFilterProvider.notifier)
                .setFilter('all'),
          ),
          const SizedBox(width: 8),

          // All Types / Deposits / Withdrawals
          FilterChip(
            selected: activeType == 'all',
            label: const Text('All Types'),
            onSelected: (_) =>
                ref.read(savingsTypeFilterProvider.notifier).setFilter('all'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: activeType == 'deposit',
            avatar: const Icon(
              Icons.arrow_downward,
              size: 16,
              color: Color(0xFF10B981),
            ),
            label: const Text('Deposits'),
            onSelected: (_) => ref
                .read(savingsTypeFilterProvider.notifier)
                .setFilter(activeType == 'deposit' ? 'all' : 'deposit'),
          ),
          const SizedBox(width: 8),
          FilterChip(
            selected: activeType == 'withdrawal',
            avatar: const Icon(
              Icons.arrow_upward,
              size: 16,
              color: Color(0xFFEF4444),
            ),
            label: const Text('Withdrawals'),
            onSelected: (_) => ref
                .read(savingsTypeFilterProvider.notifier)
                .setFilter(activeType == 'withdrawal' ? 'all' : 'withdrawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingTile(
    BuildContext context,
    Saving saving,
    bool isDark,
    bool isVault,
  ) {
    final meta = SavingsAccountMeta.forAccount(saving.account);
    final isDeposit = saving.isDeposit;
    final color = isDeposit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        onTap: () => _editSaving(context, saving),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              isDeposit ? 'Deposit' : 'Withdrawal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meta.icon, size: 12, color: meta.color),
                  const SizedBox(width: 4),
                  Text(
                    meta.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: meta.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (saving.note != null && saving.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                saving.note!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${saving.transactionDate.year}-${saving.transactionDate.month.toString().padLeft(2, '0')}-${saving.transactionDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        trailing: Text(
          isVault ? '••••••' : '${isDeposit ? '+' : '-'}৳ ${saving.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_outlined,
              size: 48,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Savings Vault is Empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start saving money across your Bank, bKash, Nagad, and Cash wallets. Keep your savings isolated from regular daily expenses.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Make First Deposit'),
            onPressed: () => _openDepositDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoalsSection(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ThemeData theme,
  ) {
    final isVisible = ref.watch(savingsGoalsVisibleProvider);
    final goalsAsync = ref.watch(savingsGoalsListProvider);
    final goals = goalsAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 20,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                Text(
                  'Savings Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (goals.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${goals.where((g) => !g.isCompleted).length} active',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: isVisible ? 'Hide Goals' : 'Show Goals',
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    ref.read(savingsGoalsVisibleProvider.notifier).toggle();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Goal'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const SavingsGoalDialog(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!isVisible)
          InkWell(
            onTap: () => ref.read(savingsGoalsVisibleProvider.notifier).toggle(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey[300]!,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Savings Goals section is hidden • Tap to display',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else if (goals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No savings goals created yet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set targets for dream purchases, emergency funds, or trips.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Set First Goal'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const SavingsGoalDialog(),
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        else
          for (final goal in goals)
            _buildSavingsGoalCard(context, ref, goal, isDark, theme),
      ],
    );
  }

  Widget _buildSavingsGoalCard(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
    bool isDark,
    ThemeData theme,
  ) {
    Color parseColor(String? hex) {
      if (hex == null) return const Color(0xFF6366F1);
      try {
        final clean = hex.replaceAll('#', '');
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {
        return const Color(0xFF6366F1);
      }
    }

    final accentColor = parseColor(goal.colorHex);
    final ratio = goal.progressRatio;
    final percent = (ratio * 100).round();
    final daysLeft = goal.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: goal.isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          width: goal.isCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  goal.isCompleted ? Icons.check_circle : Icons.flag,
                  color: goal.isCompleted
                      ? const Color(0xFF10B981)
                      : accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (goal.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Goal Reached!',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (goal.category != null) ...[
                          Text(
                            goal.category!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                        ],
                        if (daysLeft != null)
                          Text(
                            daysLeft >= 0
                                ? '$daysLeft days left'
                                : '${-daysLeft} days past target',
                            style: TextStyle(
                              fontSize: 11,
                              color: daysLeft < 0
                                  ? Colors.redAccent
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          )
                        else
                          Text(
                            'No deadline set',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(
                goal.isCompleted ? const Color(0xFF10B981) : accentColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.watch(vaultModeProvider)
                    ? '•••••• / ••••••'
                    : '৳${formatMoney(goal.savedAmount)} / ৳${formatMoney(goal.targetAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Goal',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => SavingsGoalDialog(existingGoal: goal),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openContributeDialog(context, ref, goal),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14),
                        SizedBox(width: 4),
                        Text('Add Funds', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openContributeDialog(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Contribute to ${goal.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target: ৳${formatMoney(goal.targetAmount)} • Currently saved: ৳${formatMoney(goal.savedAmount)}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount to Add (৳)',
                prefixText: '৳ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in [100, 500, 1000, 2000, 5000])
                  ActionChip(
                    label: Text('+৳$preset'),
                    onPressed: () => controller.text = preset.toString(),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(controller.text) ?? 0.0;
              if (amt > 0) {
                await ref
                    .read(savingsGoalsListProvider.notifier)
                    .contribute(goal.id, amt);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ৳$amt to ${goal.title}!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Deposit to Goal'),
          ),
        ],
      ),
    );
  }
}
