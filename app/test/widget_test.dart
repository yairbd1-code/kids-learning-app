import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_learning_app/screens/login_screen.dart';
import 'package:kids_learning_app/services/auth_service.dart';

void main() {
  testWidgets('Login screen shows the login form by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: LoginScreen(authService: AuthService(), onAuthenticated: () {}),
        ),
      ),
    );

    expect(find.text('התחברות'), findsWidgets);
    expect(find.text('אימייל'), findsOneWidget);
    expect(find.text('סיסמה'), findsOneWidget);
  });
}
