
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:boardmap_project/main.dart';

void main() {
  group('BoardMap application', () {
    testWidgets('displays the BoardMap login screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const BoardMapApp());

      expect(find.text('BoardMap'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Email or username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows errors when login fields are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const BoardMapApp());

      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(
        find.text('Please enter your password.'),
        findsOneWidget,
      );
    });

    testWidgets('opens the registration form', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const BoardMapApp());

      final registerButton = find.widgetWithText(
        OutlinedButton,
        'Create an account',
      );

      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
    });
  });
}
