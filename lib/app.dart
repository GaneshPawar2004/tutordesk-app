import 'package:flutter/material.dart';

import 'core/navigation/app_shell.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/app_scope.dart';
import 'data/app_state.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/role_selection_screen.dart';
import 'shared/widgets/widgets.dart';

class TuitionApp extends StatefulWidget {
  const TuitionApp({super.key, this.state});

  /// Injected in tests (offline sample data). Otherwise the app connects to
  /// the TutorDesk backend.
  final AppState? state;

  @override
  State<TuitionApp> createState() => _TuitionAppState();
}

class _TuitionAppState extends State<TuitionApp> {
  late final AppState _state = widget.state ?? AppState.remote();

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

/// Connected: restores the saved login, then shows sign-in or the app.
/// Offline (tests): shows the demo role picker.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  var _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    if (app.isRemote) {
      _restoring = true;
      app
          .restoreSession()
          .catchError((Object e) {
            _error = e is ApiException
                ? e.message
                : 'Could not restore your session.';
            return false;
          })
          .whenComplete(() {
            if (mounted) setState(() => _restoring = false);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final Widget child;
    if (_restoring) {
      child = const Scaffold(
        key: ValueKey('splash'),
        backgroundColor: AppColors.background,
        body: LoadingIndicator(label: 'Connecting to your tuition…'),
      );
    } else if (app.isSignedIn) {
      _error = null;
      child = AppShell(key: ValueKey('${app.role}-${app.currentStaff?.id}'));
    } else if (app.isRemote) {
      child = AuthScreen(key: const ValueKey('auth'), initialError: _error);
    } else {
      child = const RoleSelectionScreen();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: child,
    );
  }
}
