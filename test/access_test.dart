import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teachers_app/data/app_state.dart';
import 'package:teachers_app/main.dart';

import 'fake_api.dart';

void main() {
  testWidgets('trial ended → access screen instead of the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final fake = FakeApi()..accessAllowed = false;
    await tester.pumpWidget(const TeachersApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number or email'),
      'teacher@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Free trial has ended'), findsOneWidget);
    expect(find.text('support@example.com'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    // The admin allows the tuition → "check again" opens the app.
    fake.accessAllowed = true;
    await tester.tap(find.textContaining('CHECK AGAIN'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    await appState.logout();
  });
}
