import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/app/home_hub_app.dart';
import 'package:home_hub/core/widgets/async_state_view.dart';

void main() {
  testWidgets('home navigation and theme switch are available', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HomeHubApp()));
    await tester.pumpAndSettle();

    expect(find.text('What matters right now?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to Flower Mode'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to Dark Mode'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('HomeHub'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('expenses can be opened from Home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HomeHubApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();

    expect(find.text('Expenses is ready for its phase.'), findsOneWidget);
  });

  testWidgets('async error shows a retry action without exposing details', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AsyncStateView<int>(
              state: AsyncError<int>(
                Exception('private detail'),
                StackTrace.current,
              ),
              dataBuilder: (value) => Text('$value'),
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('We couldn’t load this yet.'), findsOneWidget);
    expect(find.textContaining('private detail'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('async loading shows progress', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AsyncStateView<int>(
              state: const AsyncLoading<int>(),
              dataBuilder: (value) => Text('$value'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
