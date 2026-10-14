import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/weather_provider.dart';
import 'dart:ui';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../calendar/presentation/providers/calendar_provider.dart';
import '../../../calendar/presentation/widgets/dashboard_calendar.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/presentation/widgets/city_picker.dart';
import '../../../wishlist/presentation/providers/wishlist_provider.dart';
import '../../../../main_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load your dashboard."),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(dashboardSummaryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) {
          final initials = (user?.name ?? '')
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
          final avatarUrl = user?.avatarUrl;
          final greeting = Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                // Shown until the photo loads, or if there isn't one.
                child: Text(
                  initials.isEmpty ? '?' : initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      user?.name ?? 'Guest',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final weather = GestureDetector(
            onTap: () => showCityPicker(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: _buildGlassCard(
                context,
                isDark: isDark,
                child: _buildWeather(context, ref),
              ),
            ),
          );
          final productivity = _buildGlassCard(
            context,
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Productivity Score',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${summary.productivityScore}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: summary.productivityScore / 100,
                    minHeight: 8,
                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
          );
          final stats = Row(
            children: [
              Expanded(
                child: _buildGlassCard(
                  context,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.purpleAccent,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Today's tasks",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.tasksTotal == 0
                            ? 'Nothing due today'
                            : '${summary.tasksCompleted} / ${summary.tasksTotal} done',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
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
                      const Icon(
                        Icons.repeat,
                        color: Colors.orangeAccent,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Habits',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.habitsCompleted} / ${summary.habitsTotal} done',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          final budgetCard = Builder(
            builder: (context) {
              final budget = summary.monthlyBudget > 0
                  ? summary.monthlyBudget
                  : summary.monthlyIncome;
              final spent = summary.monthlyExpenses;
              final left = budget - spent;
              final isOverspent = left < 0;

              return Column(
                children: [
                  if (isOverspent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Warning: You have exceeded your monthly budget by ${formatMoney(left.abs())}!',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color:
                          theme.cardTheme.color ??
                          (isDark ? const Color(0xFF1E1E2C) : Colors.white),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.05,
                          ),
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
                            Icon(
                              Icons.account_balance_wallet,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Budget Overview',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Income',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatMoney(summary.monthlyIncome),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueAccent,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        summary.monthlyBudget > 0
                                            ? 'Target Budget'
                                            : 'Est. Budget',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatMoney(budget),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent,
                                            ),
                                      ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Spent',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatMoney(spent),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orangeAccent,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isOverspent ? 'Overspent' : 'Remaining',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatMoney(left),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isOverspent
                                                  ? Colors.redAccent
                                                  : Colors.green,
                                            ),
                                      ),
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
                            value: budget > 0
                                ? (spent / budget).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 12,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOverspent
                                  ? Colors.redAccent
                                  : (budget > 0 && spent / budget > 0.8
                                        ? Colors.orangeAccent
                                        : Colors.greenAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
          final recent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (summary.recentActivity.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No recent activity.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: summary.recentActivity.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = summary.recentActivity[index];
                    final isTask = item.type == 'task';

                    return Container(
                      decoration: BoxDecoration(
                        color:
                            theme.cardTheme.color ??
                            (isDark ? const Color(0xFF1E1E2C) : Colors.white),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isTask
                                ? Colors.blueAccent.withValues(alpha: 0.2)
                                : (item.isIncome == true
                                      ? Colors.greenAccent.withValues(
                                          alpha: 0.2,
                                        )
                                      : Colors.redAccent.withValues(
                                          alpha: 0.2,
                                        )),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isTask
                                ? Icons.check_circle_outline
                                : (item.isIncome == true
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward),
                            color: isTask
                                ? Colors.blueAccent
                                : (item.isIncome == true
                                      ? Colors.green
                                      : Colors.redAccent),
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.date.day}/${item.date.month}/${item.date.year} • ${item.subtitle}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isTask || item.amount == null
                            ? null
                            : Text(
                                '${item.isIncome == true ? '+' : '-'}${formatMoney(item.amount!)}',
                                style: TextStyle(
                                  color: item.isIncome == true
                                      ? Colors.green
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    );
                  },
                ),
            ],
          );
          const gap = SizedBox(height: 16);

          return RefreshIndicator(
            onRefresh: () {
              ref.invalidate(calendarMonthProvider);
              ref.invalidate(calendarDayProvider);
              return ref.refresh(dashboardSummaryProvider.future);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Two columns once there's room, so everything fits above the fold on desktop.
                final wide = constraints.maxWidth >= 960;
                final calendar = _buildGlassCard(
                  context,
                  isDark: isDark,
                  child: DashboardCalendar(compact: !wide),
                );
                final accountsCard = _buildAccountsCard(
                  context,
                  isDark: isDark,
                  balances: summary.accountBalances,
                );
                final wishlistCard = _buildWishlistCard(
                  context,
                  ref,
                  isDark: isDark,
                );
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: wide
                      ? [
                          greeting,
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    weather,
                                    gap,
                                    productivity,
                                    gap,
                                    stats,
                                    gap,
                                    calendar,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    budgetCard,
                                    const SizedBox(height: 24),
                                    accountsCard,
                                    const SizedBox(height: 24),
                                    wishlistCard,
                                    const SizedBox(height: 24),
                                    recent,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ]
                      : [
                          greeting,
                          const SizedBox(height: 24),
                          weather,
                          gap,
                          productivity,
                          gap,
                          stats,
                          gap,
                          calendar,
                          gap,
                          budgetCard,
                          gap,
                          accountsCard,
                          gap,
                          wishlistCard,
                          const SizedBox(height: 32),
                          recent,
                        ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeather(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = ref.watch(weatherLocationProvider);
    final weatherAsync = ref.watch(weatherProvider);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: Colors.grey);

    Widget badge(IconData icon, Color color) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 32),
    );

    return weatherAsync.when(
      data: (weather) => Row(
        children: [
          badge(weather.icon, weather.color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.label,
                  style: muted,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${weather.temperature.round()}°C - ${weather.description}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Feels like ${weather.feelsLike.round()}° · Humidity ${weather.humidity}% · Wind ${weather.windSpeed.round()} km/h',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.edit_location_alt_outlined,
            color: Colors.grey,
            size: 20,
          ),
        ],
      ),
      loading: () => Row(
        children: [
          badge(Icons.cloud_outlined, Colors.blueAccent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location.label, style: muted),
                Text('Loading weather…', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
      error: (_, _) => Row(
        children: [
          badge(Icons.cloud_off_rounded, Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location.label, style: muted),
                Text('Weather unavailable', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(weatherProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context, {
    required Widget child,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAccountsCard(
    BuildContext context, {
    required bool isDark,
    required Map<String, double> balances,
  }) {
    final theme = Theme.of(context);

    const accounts = [
      (
        key: 'cash',
        label: 'Cash',
        icon: Icons.wallet,
        color: Color(0xFF34D399),
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
        key: 'bank',
        label: 'Bank',
        icon: Icons.account_balance,
        color: Color(0xFF60A5FA),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'My Accounts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: accounts.map((acc) {
              final balance = balances[acc.key] ?? 0.0;
              final isNegative = balance < 0;
              return Container(
                decoration: BoxDecoration(
                  color: acc.color.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: acc.color.withValues(alpha: isDark ? 0.3 : 0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: acc.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(acc.icon, color: acc.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            acc.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatMoney(balance),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isNegative
                                  ? Colors.redAccent
                                  : acc.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
  }) {
    final stats = ref.watch(wishlistStatsProvider);
    final theme = Theme.of(context);
    final percent = (stats.progress * 100).round();

    return _buildGlassCard(
      context,
      isDark: isDark,
      child: InkWell(
        onTap: () {
          ref.read(selectedTabProvider.notifier).selectTab(AppTab.wishlist);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wishlist Target',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        stats.totalCount == 0
                            ? 'Plan what you wish to acquire'
                            : '${stats.wantedCount} wanted · ${stats.purchasedCount} acquired',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey[400],
                ),
              ],
            ),
            if (stats.totalCount > 0) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatMoney(stats.totalValue),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$percent% acquired',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: stats.progress,
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
