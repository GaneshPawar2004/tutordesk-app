import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teachers_app/data/app_state.dart';
import 'package:teachers_app/main.dart';

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _enter(WidgetTester tester, String hint, String text) async {
  final f = find.widgetWithText(TextFormField, hint).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
}

Finder _page() => find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

void main() {
  testWidgets('signup → OTP → dashboard', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(const TeachersApp());

    await _tap(tester, find.text('Create Account'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Full Name', 'Asha Patil');
    await _enter(tester, 'Email address', 'asha@example.com');
    await _enter(tester, 'Mobile number', '9876543210');
    await _enter(tester, 'Password', 'secret1');
    await _enter(tester, 'Confirm Password', 'secret1');
    await tester.ensureVisible(find.text('Send Verification Code'));
    await _tap(tester, find.text('Send Verification Code'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Verify Email'), findsOneWidget);
    expect(find.text('as**@example.com'), findsOneWidget);
    final boxes = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    appState.logout();
  });

  testWidgets('forgot password → OTP → reset → login', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(const TeachersApp());

    await _tap(tester, find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Registered email address', 'asha@example.com');
    await _tap(tester, find.text('Send OTP'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Enter OTP'), findsOneWidget);

    // Paste the whole code into the first box.
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Create a new password for your account'), findsOneWidget);

    await _enter(tester, 'New Password', 'newpass');
    await _enter(tester, 'Confirm New Password', 'newpass');
    await _tap(tester, find.widgetWithText(InkWell, 'Reset Password'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('main teacher flow', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(const TeachersApp());

    // Login
    await _enter(tester, 'Mobile number or email', 'teacher@example.com');
    await _enter(tester, 'Password', 'secret1');
    await _tap(tester, find.text('Sign In'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Free Trial — 14 days remaining'), findsOneWidget);

    // Classes tab → add class
    await _tap(tester, find.text('Classes').last);
    await tester.pumpAndSettle();
    expect(
      find.text('No classes yet. Click + to add a class.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _enter(tester, 'Enter class name', 'Class 5');
    await _tap(tester, find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('Class: Class 5'), findsOneWidget);
    expect(find.text('Class added successfully!'), findsOneWidget);

    // Open class → add students
    await _tap(tester, find.text('Class: Class 5'));
    await tester.pumpAndSettle();
    for (final (name, roll) in [
      ('Ganesh Pawar', '10'),
      ('Roshan Bachhav', '11'),
    ]) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await _enter(tester, 'Enter student name', name);
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      await _enter(tester, 'Enter roll number', roll);
      await _enter(tester, 'Enter total fees', '15000');
      await _tap(tester, find.text('ADD'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Ganesh Pawar'), findsOneWidget);
    expect(find.text('Roll: 11'), findsOneWidget);

    // Student actions dialog
    await _tap(tester, find.text('Ganesh Pawar'));
    await tester.pumpAndSettle();
    expect(find.text('VIEW FULL PROFILE'), findsOneWidget);
    await _tap(tester, find.text('VIEW FULL PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('Student Profile'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Attendance: mark Roshan absent and save
    await _tap(tester, find.text('Attendance'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Roshan Bachhav'),
      200,
      scrollable: _page(),
    );
    await _tap(tester, find.text('Absent').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('SAVE ATTENDANCE'),
      -200,
      scrollable: _page(),
    );
    await _tap(tester, find.text('SAVE ATTENDANCE'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Present: 1 · Absent: 1 · Leave: 0'),
      findsOneWidget,
    );
    await _tap(tester, find.text('OK'));
    await tester.pumpAndSettle();

    // Tests: add a test → edit marks opens
    await _tap(tester, find.text('Tests'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _enter(tester, 'e.g. Mathematics', 'Mathematics');
    await _enter(tester, 'e.g. 50', '50');
    await _tap(tester, find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Marks'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Marks').first,
      '42',
    );
    await tester.scrollUntilVisible(
      find.text('SAVE'),
      200,
      scrollable: _page(),
    );
    await _tap(tester, find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Graded: 1 / 2 students'), findsOneWidget);

    // Fees: collect from Ganesh
    await _tap(tester, find.text('Fees'));
    await tester.pumpAndSettle();
    expect(find.text('Fees : Class 5'), findsOneWidget);
    expect(find.text('₹30000'), findsNWidgets(2));
    await _tap(tester, find.text('Ganesh Pawar'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Enter amount', '5000');
    await _tap(tester, find.text('COLLECT'));
    await tester.pumpAndSettle();
    expect(find.text('₹25000'), findsOneWidget);

    // Back to dashboard → Users
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Home'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5)); // let snackbar expire
    await tester.pumpAndSettle();
    expect(find.text('Students'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Users'),
      200,
      scrollable: _page(),
    );
    await _tap(tester, find.text('Users'));
    await tester.pumpAndSettle();
    expect(find.text('No users yet. Tap + to add.'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _enter(tester, "User's name", 'Tanmay Gundre');
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await _enter(tester, 'Email used to sign in', 'tanmay@example.com');
    await _enter(tester, 'Min 6 characters', 'secret1');
    await _tap(tester, find.text('SAVE USER'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5)); // let snackbar expire
    await tester.pumpAndSettle();

    // Reports
    await _tap(tester, find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Class 5 (2 students)'), findsOneWidget);
    expect(find.text('50%'), findsNWidgets(2));
  });
}
