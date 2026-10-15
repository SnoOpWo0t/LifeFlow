import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/tasks/presentation/screens/tasks_screen.dart';
import 'features/expenses/presentation/screens/expense_screen.dart';
import 'features/habits/presentation/screens/habit_screen.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/wishlist/presentation/screens/wishlist_screen.dart';
import 'features/wishlist/presentation/providers/wishlist_provider.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/analytics/presentation/providers/analytics_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/calendar/presentation/providers/calendar_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';

/// Screen index constants used across the app.
abstract class AppTab {
  static const int dashboard = 0;
  static const int tasks = 1;
  static const int expenses = 2;
  static const int habits = 3;
  static const int analytics = 4;
  static const int wishlist = 5;
  static const int settings = 6;
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
      }
    });
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    // On mobile, Wishlist (5) and Settings (6) are housed inside the "More" button (nav index 5)
    final int mobileNavIndex = currentIndex <= AppTab.analytics
        ? currentIndex
        : 5;

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
                if (index == 5) {
                  _showMoreBottomSheet(context, ref, currentIndex);
                } else {
                  ref.read(selectedTabProvider.notifier).selectTab(index);
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
                  icon: Icon(Icons.repeat),
                  selectedIcon: Icon(Icons.repeat),
                  label: 'Habits',
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
    final wishlistStats = ref.read(wishlistStatsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'More Options',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Wishlist Tile
                _buildMoreTile(
                  context: ctx,
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.card_giftcard,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Wishlist',
                  subtitle: wishlistStats.totalCount > 0
                      ? '${wishlistStats.wantedCount} wanted · ${wishlistStats.purchasedCount} acquired'
                      : 'Target savings & dream purchases',
                  badgeText: wishlistStats.totalCount > 0
                      ? '${wishlistStats.totalCount}'
                      : null,
                  isSelected: currentScreen == AppTab.wishlist,
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(selectedTabProvider.notifier)
                        .selectTab(AppTab.wishlist);
                  },
                ),
                const SizedBox(height: 10),

                // Settings Tile
                _buildMoreTile(
                  context: ctx,
                  theme: theme,
                  isDark: isDark,
                  icon: Icons.settings_outlined,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Settings',
                  subtitle: 'Preferences, appearance, weather & account',
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
          ),
        );
      },
    );
  }

  Widget _buildMoreTile({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badgeText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? Colors.black12 : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : (isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
