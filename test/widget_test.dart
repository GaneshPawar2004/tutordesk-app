import 'package:flutter_test/flutter_test.dart';

import 'package:teachers_app/main.dart';

import 'fake_api.dart';

void main() {
  testWidgets('App starts on the login screen', (tester) async {
    FakeApi();
    await tester.pumpWidget(const TeachersApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
