import 'package:flutter/material.dart';

import '../../widgets/floating_nav_bar.dart';
import '../reports/reports_screen.dart';
import '../pushup/pushup_screen.dart';
import '../settings/settings_screen.dart';
import '../food/food_scanner_screen.dart';
import 'dashboard_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [
    DashboardTab(),
    ReportsScreen(),
    PushupScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
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
            icon: Icons.fitness_center_outlined,
            activeIcon: Icons.fitness_center_rounded,
            label: 'Push-ups'
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
