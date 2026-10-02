import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/flower_backdrop.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets(
      'flower background settles and does not block taps (reduced motion: $reduceMotion)',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: FlowerBackdrop(child: child!),
            ),
            home: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Tap'),
                ),
              ),
            ),
          ),
        );
        final frames = await tester.pumpAndSettle();
        if (reduceMotion) expect(frames, lessThan(10));
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.tap(find.text('Tap'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
