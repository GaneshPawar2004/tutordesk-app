import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TeachersApp());
}

class TeachersApp extends StatelessWidget {
  const TeachersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaksha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Respect the phone's font-size setting, but within limits so very
      // large system fonts can't break layouts.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child!,
        );
      },
      home: const LoginScreen(),
    );
  }
}
