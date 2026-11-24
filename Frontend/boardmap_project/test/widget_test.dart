import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:boardmap_project/screens/landing_screen.dart';
import 'package:boardmap_project/screens/login_screen.dart';

void main() {
  group('BoardMap application', () {
    testWidgets('shows the public landing page and sign-up action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
      expect(find.text('BoardMap'), findsOneWidget);
      expect(find.text('Find a place\nto call home.'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('landing feature cards fit phone, tablet, and desktop widths', (
      WidgetTester tester,
    ) async {
      for (final size in const [
        Size(320, 800),
        Size(768, 1024),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const MaterialApp(home: LandingScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Viewport: $size');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('displays the BoardMap login screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.text('BoardMap'), findsOneWidget);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Email or username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows errors when login fields are empty', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Please enter a password.'), findsOneWidget);
    });

    testWidgets('opens the registration form', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      final registerButton = find.widgetWithText(
        OutlinedButton,
        'Create an account',
      );

      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(find.text('How will you use BoardMap?'), findsOneWidget);
      expect(find.text('Renter'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);

      await tester.tap(find.text('Renter'));
      await tester.tap(find.text('Continue to sign up'));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.textContaining('First name'), findsOneWidget);
      expect(find.textContaining('Last name'), findsOneWidget);
      expect(find.textContaining('Email address'), findsOneWidget);
      expect(find.textContaining('Contact number'), findsOneWidget);
      expect(find.textContaining('Confirm password'), findsOneWidget);
    });
  });
}
