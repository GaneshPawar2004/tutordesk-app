import 'package:flutter/material.dart';

import 'core/navigation/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'data/app_scope.dart';
import 'data/app_state.dart';
import 'features/onboarding/role_selection_screen.dart';

class TuitionApp extends StatefulWidget {
  const TuitionApp({super.key, this.state});

  /// Injected in tests; otherwise a fresh in-memory state is created.
  final AppState? state;

  @override
  State<TuitionApp> createState() => _TuitionAppState();
}

class _TuitionAppState extends State<TuitionApp> {
  late final AppState _state = widget.state ?? AppState();

  @override
  void dispose() {
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'TutorDesk',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const _RootGate(),
      ),
    );
  }
}

/// Shows role selection until a demo role is chosen, then the app shell.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: app.isSignedIn
          ? AppShell(key: ValueKey('${app.role}-${app.currentStaff?.id}'))
          : const RoleSelectionScreen(),
    );
  }
}
