import 'package:flutter/material.dart';

import '../classes/classes_screen.dart';
import 'dashboard_screen.dart';

/// Root after login: bottom navigation between Dashboard and Classes.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onOpenClasses: () => _goTo(1)),
            ClassesScreen(onBack: () => _goTo(0)),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_outlined),
              label: 'Classes',
            ),
          ],
        ),
      ),
    );
  }
}
