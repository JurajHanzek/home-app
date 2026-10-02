import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/flower_navigation_frame.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('floral menu remains usable and settles ($reduceMotion)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      const labels = ['Home', 'Tasks', 'Meals', 'Calendar', 'Shopping'];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
              padding: const EdgeInsets.only(bottom: 24),
            ),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: FlowerNavigationFrame(
                enabled: true,
                selectedIndex: selected,
                child: NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (value) =>
                      setState(() => selected = value),
                  destinations: [
                    for (final label in labels)
                      NavigationDestination(
                        icon: const Icon(Icons.local_florist),
                        label: label,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final frames = await tester.pumpAndSettle();
      expect(frames, reduceMotion ? lessThan(10) : greaterThan(10));
      for (final index in [1, 2, 3, 4, 0]) {
        await tester.tap(find.text(labels[index]));
        await tester.pump();
        final frames = await tester.pumpAndSettle();
        expect(frames, reduceMotion ? lessThan(10) : greaterThan(10));
        expect(selected, index);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
