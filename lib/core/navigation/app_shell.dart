import 'package:flutter/material.dart';

import '../../features/attendance/attendance_overview_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/students/student_directory_screen.dart';
import '../../shared/widgets/custom_bottom_nav.dart';

enum ShellTab { home, students, attendance, more }

/// Role-aware navigation shell with a persistent four-item bottom bar.
/// Tabs live in an [IndexedStack] so scroll position, search text and filters
/// survive switching tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static void goTo(BuildContext context, ShellTab tab) {
    context.findAncestorStateOfType<_AppShellState>()?._select(tab.index);
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  static const _items = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Students',
    ),
    NavItem(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
      label: 'Attendance',
    ),
    NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'More',
    ),
  ];

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: const [
              DashboardScreen(),
              StudentDirectoryScreen(),
              AttendanceOverviewScreen(),
              MoreScreen(),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          items: _items,
          currentIndex: _index,
          onTap: _select,
        ),
      ),
    );
  }
}
