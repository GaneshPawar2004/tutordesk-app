import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teachers_app/data/app_state.dart';
import 'package:teachers_app/main.dart';

import 'fake_api.dart';

void main() {
  testWidgets(
    'saved attendance shows who saved it; absent SMS only once and only after saving',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final fake = FakeApi();
      final today = AppState.dateKey(DateTime.now());
      fake.classes.add({
        'id': 'c1',
        'name': 'Class 9',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      for (final (id, name) in [('s1', 'Ravi'), ('s2', 'Sita')]) {
        fake.students.add({
          'id': id,
          'class': 'c1',
          'name': name,
          'fatherName': '',
          'contact': '',
          'parentMobile': '9811100001',
          'rollNo': '',
          'email': '',
          'totalFees': 0,
          'feesPaid': 0,
          'disabled': false,
          'createdAt': '2026-01-01T00:00:00Z',
        });
      }
      // Ravi was saved absent and his parent already got the SMS.
      fake.attendance['c1|$today'] = [
        {'student': 's1', 'status': 'absent'},
        {'student': 's2', 'status': 'present'},
      ];
      fake.attendanceVersion['c1|$today'] = 1;
      fake.absentSms['c1|$today'] = {'s1': 'sent'};

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

      await tester.tap(find.text('Classes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class: Class 9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attendance'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Saved by Asha Patil'), findsOneWidget);
      expect(find.text('SMS sent'), findsOneWidget);

      // Nothing new to send: Ravi's parent already got it.
      final sms = find.text('SMS ABSENT PARENTS');
      await tester.scrollUntilVisible(
        sms,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(sms);
      await tester.pumpAndSettle();
      expect(find.textContaining('already got the SMS'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Unsaved change → asked to save before any SMS.
      await tester.scrollUntilVisible(
        find.text('Sita'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Absent').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('You have unsaved changes'), findsOneWidget);
      await tester.scrollUntilVisible(
        sms,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(sms);
      await tester.pumpAndSettle();
      expect(find.text('Save first?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Leaving with unsaved changes asks first.
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      expect(find.text('Discard attendance changes?'), findsOneWidget);
      await tester.tap(find.text('DISCARD'));
      await tester.pumpAndSettle();
      await appState.logout();
    },
  );
}
