import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teachers_app/data/app_state.dart';
import 'package:teachers_app/main.dart';

import 'fake_api.dart';

void main() {
  testWidgets('unsent SMS from another phone show up and can be opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Staff 4 sent 100 of 120; 20 are left.
    final fake = FakeApi();
    fake.smsBatches.add({
      'id': 'b1',
      'title': 'Class 10 · Absent on 03-11-2026',
      'kind': 'absent',
      'createdAt': DateTime.utc(2026, 11, 3).toIso8601String(),
      'createdBy': 'Staff Four',
      'messages': [
        for (var i = 1; i <= 120; i++)
          {
            'id': 'm$i',
            'name': 'Student $i',
            'phone': '98000000${i.toString().padLeft(2, '0')}',
            'body': 'Dear Parent, Student $i was absent.',
            'status': i <= 100 ? 'sent' : 'pending',
          },
      ],
    });

    await tester.pumpWidget(const TeachersApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile number or email'),
      'admin@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret1',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('20 parent SMS not sent yet'), findsOneWidget);
    await tester.tap(find.text('20 parent SMS not sent yet'));
    await tester.pumpAndSettle();

    expect(find.text('Pending SMS'), findsOneWidget);
    expect(find.text('Class 10 · Absent on 03-11-2026'), findsOneWidget);
    expect(find.text('SEND 20 FROM MY PHONE'), findsOneWidget);
    expect(find.textContaining('100 of 120 sent · 20 left'), findsOneWidget);

    // VIEW lists exactly who is left.
    await tester.tap(find.text('VIEW'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent yet (20)'), findsOneWidget);
    expect(find.text('Student 101'), findsOneWidget);
    await appState.logout();
  });
}
