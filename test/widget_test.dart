import 'package:flutter_test/flutter_test.dart';

import 'package:teachers_app/main.dart';

void main() {
  testWidgets('App starts on the login screen', (tester) async {
    await tester.pumpWidget(const TeachersApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
