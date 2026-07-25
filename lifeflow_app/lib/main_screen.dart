import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/tasks/presentation/screens/tasks_screen.dart';
import 'features/expenses/presentation/screens/expense_screen.dart';
import 'features/habits/presentation/screens/habit_screen.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TasksScreen(),
    const ExpenseScreen(),
    const HabitScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    
    return Scaffold(
      body: isDesktop ? Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.check_circle_outline), label: Text('Tasks')),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet), label: Text('Expenses')),
              NavigationRailDestination(icon: Icon(Icons.repeat), label: Text('Habits')),
              NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('Analytics')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_currentIndex]),
        ],
      ) : _screens[_currentIndex],
      bottomNavigationBar: isDesktop ? null : NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.repeat), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
