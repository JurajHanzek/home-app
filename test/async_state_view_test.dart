import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/widgets/async_state_view.dart';

void main() {
  testWidgets('async error hides exception details and exposes retry', (
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
