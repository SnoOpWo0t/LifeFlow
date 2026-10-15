import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/tasks/presentation/screens/tasks_screen.dart';
import 'features/expenses/presentation/screens/expense_screen.dart';
import 'features/habits/presentation/screens/habit_screen.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/wishlist/presentation/screens/wishlist_screen.dart';
import 'features/savings/presentation/screens/savings_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/calendar/presentation/providers/calendar_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/insights/data/insights_repository.dart';

import 'features/bills/presentation/screens/bills_screen.dart';
import 'features/bills/presentation/widgets/bill_dialog.dart';
import 'features/savings/presentation/widgets/savings_goal_dialog.dart';
import 'features/savings/presentation/widgets/savings_dialog.dart';
import 'features/wishlist/presentation/widgets/wishlist_dialog.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

/// Screen index constants used across the app.
abstract class AppTab {
  static const int dashboard = 0;
  static const int tasks = 1;
  static const int expenses = 2;
  static const int habits = 3;
  static const int analytics = 4;
  static const int wishlist = 5;
  static const int settings = 6;
  static const int savings = 7;
  static const int bills = 8;
}

/// Global provider for the active bottom/rail navigation tab index.
/// Allows any screen to switch tabs programmatically.
final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(
  SelectedTabNotifier.new,
);

class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() {
    // Start on the dashboard for every sign-in (otherwise the next user would
    // open on whatever tab the previous one logged out from).
    ref.watch(authProvider.select((auth) => auth.value?.id));
    return AppTab.dashboard;
  }

  void selectTab(int index) => state = index;
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const List<Widget> _screens = [
    DashboardScreen(), // 0
    TasksScreen(), // 1
    ExpenseScreen(), // 2
    HabitScreen(), // 3
    AnalyticsScreen(), // 4
    WishlistScreen(), // 5
    SettingsScreen(), // 6
    SavingsScreen(), // 7
    BillsScreen(), // 8
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(selectedTabProvider);

    // IndexedStack keeps every tab alive, so summary screens no longer reload
    // on their own. Refresh them whenever they're opened, so changes made in
    // other tabs (tasks done, habits checked, money added) show up.
    ref.listen(selectedTabProvider, (previous, next) {
      if (previous == next) return;
      if (next == AppTab.dashboard) {
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(calendarMonthProvider);
        ref.invalidate(calendarDayProvider);
      } else if (next == AppTab.analytics) {
        ref.invalidate(weeklyAnalyticsProvider);
        ref.invalidate(insightProvider);
      }
    });
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    // On mobile: Dashboard(0), Tasks(1), Expenses(2), Analytics(3 in nav), More(4 in nav)
    // Habits, Wishlist, Savings and Settings live inside the "More" sheet.
    final int mobileNavIndex;
    switch (currentIndex) {
      case AppTab.dashboard:
        mobileNavIndex = 0;
        break;
      case AppTab.tasks:
        mobileNavIndex = 1;
        break;
      case AppTab.expenses:
        mobileNavIndex = 2;
        break;
      case AppTab.analytics:
        mobileNavIndex = 3;
        break;
      default:
        // Habits, Wishlist, Settings, Savings → highlight "More"
        mobileNavIndex = 4;
    }

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) {
                    ref.read(selectedTabProvider.notifier).selectTab(index);
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Image.asset(
                      'assets/images/logo_mark.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.check_circle_outline),
                      selectedIcon: Icon(Icons.check_circle),
                      label: Text('Tasks'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: Text('Expenses'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.repeat),
                      selectedIcon: Icon(Icons.repeat),
                      label: Text('Habits'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('Analytics'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.card_giftcard_outlined),
                      selectedIcon: Icon(Icons.card_giftcard),
                      label: Text('Wishlist'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.savings_outlined),
                      selectedIcon: Icon(Icons.savings),
                      label: Text('Savings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.notifications_none_outlined),
                      selectedIcon: Icon(Icons.notifications),
                      label: Text('Bills'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // Keep pages readable on wide monitors and preserve tab state
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: IndexedStack(
                        index: currentIndex,
                        children: _screens,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: mobileNavIndex,
              onDestinationSelected: (index) {
                // Map mobile nav indices back to AppTab constants
                const mobileToAppTab = [
                  AppTab.dashboard,  // 0
                  AppTab.tasks,      // 1
                  AppTab.expenses,   // 2
                  AppTab.analytics,  // 3
                ];
                if (index == 4) {
                  _showMoreBottomSheet(context, ref, currentIndex);
                } else {
                  ref.read(selectedTabProvider.notifier).selectTab(mobileToAppTab[index]);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: 'Tasks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Expenses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Analytics',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu),
                  selectedIcon: Icon(Icons.menu_open),
                  label: 'More',
                ),
              ],
            ),
    );
  }

  void _showMoreBottomSheet(
    BuildContext context,
    WidgetRef ref,
    int currentScreen,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.read(authProvider).value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF13151D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: MORE + Close Button (Reference Image)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MORE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                      color: isDark ? Colors.white60 : Colors.black54,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4-Column Launcher Grid (Reference Image)
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.repeat,
                      label: 'Habits',
                      isSelected: currentScreen == AppTab.habits,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.habits);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.checklist_rtl_rounded,
                      label: 'To-do',
                      isSelected: currentScreen == AppTab.tasks,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.tasks);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.card_giftcard_outlined,
                      label: 'Wishlist',
                      isSelected: currentScreen == AppTab.wishlist,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.wishlist);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.pie_chart_outline,
                      label: 'Budgets',
                      isSelected: currentScreen == AppTab.expenses,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.expenses);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.track_changes_outlined,
                      label: 'Goals',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.savings);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.notifications_none_outlined,
                      label: 'Bills',
                      isSelected: currentScreen == AppTab.bills,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.bills);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.savings_outlined,
                      label: 'Savings',
                      isSelected: currentScreen == AppTab.savings,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.savings);
                      },
                    ),
                    _buildLauncherTile(
                      isDark: isDark,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      isSelected: currentScreen == AppTab.settings,
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.settings);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Prominent "+ New entry" Button (Coral Accent from Reference)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE07A5F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      shadowColor: const Color(0xFFE07A5F).withValues(alpha: 0.4),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      'New entry',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showQuickAddSheet(context, ref);
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Vault Mode Row (Privacy Shield)
                Consumer(
                  builder: (context, ref, _) {
                    final isVault = ref.watch(vaultModeProvider);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Vault Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          color: Color(0xFF10B981),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Vault Privacy Shield'),
                                      ],
                                    ),
                                    content: const Text(
                                      'When Vault Mode is active, all sensitive financial figures (wallet balances, savings reserves, monthly income, budget remaining, and bill amounts) are concealed with privacy masks (••••••).\n\nUse this in public places, transit, or when screen sharing to keep your money strictly confidential.',
                                    ),
                                    actions: [
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('Got it'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E222D) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVault
                                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.black.withValues(alpha: 0.08)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVault ? Icons.shield : Icons.shield_outlined,
                                size: 14,
                                color: isVault
                                    ? const Color(0xFF10B981)
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVault ? 'Shielded' : 'Vault',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isVault
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 20,
                                width: 32,
                                child: Switch(
                                  value: isVault,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) async {
                                    await ref
                                        .read(vaultModeProvider.notifier)
                                        .setVaultMode(val);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(
                                                val
                                                    ? Icons.shield_rounded
                                                    : Icons.shield_outlined,
                                                color: val
                                                    ? const Color(0xFF10B981)
                                                    : Colors.white,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  val
                                                      ? '🛡️ Vault Mode enabled: Balances & savings are concealed.'
                                                      : 'Vault Mode disabled: Financial amounts are visible.',
                                                ),
                                              ),
                                            ],
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Theme Row (Reference Image)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final currentMode = ref.read(themeModeProvider);
                        final nextMode = currentMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                        ref.read(themeModeProvider.notifier).setMode(nextMode);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222D) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          isDark
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_round,
                          size: 18,
                          color: isDark ? Colors.amber : Colors.indigo,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Sign Out Footer Box (Reference Image)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161922) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref.read(authProvider.notifier).logout();
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sign out',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLauncherTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE07A5F).withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF1B1E28) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE07A5F)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFFE07A5F)
                  : (isDark ? Colors.white70 : Colors.black87),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFE07A5F)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Create New Entry',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildQuickActionChip(
                      icon: Icons.checklist_rtl_rounded,
                      color: const Color(0xFF38BDF8),
                      label: 'New Task',
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.tasks);
                      },
                    ),
                    _buildQuickActionChip(
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFFF97316),
                      label: 'New Bill / Subscription',
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (c) => const BillDialog(),
                        );
                      },
                    ),
                    _buildQuickActionChip(
                      icon: Icons.track_changes_outlined,
                      color: const Color(0xFF8B5CF6),
                      label: 'Savings Goal',
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (c) => const SavingsGoalDialog(),
                        );
                      },
                    ),
                    _buildQuickActionChip(
                      icon: Icons.savings_outlined,
                      color: const Color(0xFF10B981),
                      label: 'Savings Deposit',
                      onTap: () {
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          builder: (c) => const SavingsDialog(
                            defaultType: 'deposit',
                          ),
                        );
                      },
                    ),
                    _buildQuickActionChip(
                      icon: Icons.card_giftcard,
                      color: const Color(0xFFEC4899),
                      label: 'Wishlist Target',
                      onTap: () {
                        Navigator.pop(ctx);
                        showWishlistDialog(context);
                      },
                    ),
                    _buildQuickActionChip(
                      icon: Icons.repeat,
                      color: const Color(0xFFF59E0B),
                      label: 'New Habit',
                      onTap: () {
                        Navigator.pop(ctx);
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.habits);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
