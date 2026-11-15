import 'package:flutter/material.dart';

import '../../widgets/floating_nav_bar.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../food/food_scanner_screen.dart';
import '../food/food_log_screen.dart';
import 'dashboard_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Tabs are built on first visit only: ReportsScreen fires its range
  // queries in initState, and building all four tabs eagerly made every cold
  // start pay for tabs the user never opens. Once built, a tab stays mounted
  // (IndexedStack), so its state is preserved when switching back.
  final _visited = <int>{0};

  static const _pages = [
    DashboardTab(),
    ReportsScreen(),
    FoodLogScreen(),
    SettingsScreen(),
  ];

  void _onTab(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          for (int i = 0; i < _pages.length; i++)
            _visited.contains(i) ? _pages[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _index,
        onTap: _onTab,
        centerIcon: Icons.center_focus_strong_rounded,
        onCenterTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
          );
        },
        items: const [
          (
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home'
          ),
          (
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: 'Stats'
          ),
          (
            icon: Icons.restaurant_menu_outlined,
            activeIcon: Icons.restaurant_menu_rounded,
            label: 'Meals'
          ),
          (
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile'
          ),
        ],
      ),
    );
  }
}
