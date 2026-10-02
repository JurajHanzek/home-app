import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/app/home_hub_app.dart';
import 'package:home_hub/features/auth/presentation/auth_screens.dart';

void main() {
  testWidgets('unconfigured app stays on the safe setup screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HomeHubApp()));
    await tester.pumpAndSettle();

    expect(find.text('Connect your household'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Sign up'), findsNothing);
  });

  testWidgets('Flower theme remains switchable on setup screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HomeHubApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flower Mode'));
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Connect your household'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('sign-in screen has no public account creation flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsNothing);
    expect(find.text('Sign up'), findsNothing);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
