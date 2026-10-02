import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/core/theme/font_size_controller.dart';
import 'package:home_hub/features/settings/settings_screen.dart';

void main() {
  testWidgets(
    'font-size option updates the global theme and restores persisted selection',
    (tester) async {
      var storedSize = 'normal';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fontPreferenceChannel, (call) async {
            if (call.method == 'getFontSize') return storedSize;
            if (call.method == 'setFontSize') {
              storedSize = call.arguments! as String;
              return null;
            }
            return null;
          });

      await tester.pumpWidget(const ProviderScope(child: _FontOptionsApp()));
      await tester.pumpAndSettle();
      final normalFontSize = _appearanceFontSize(tester);
      expect(normalFontSize, greaterThan(0));
      expect(_selectedSize(tester), AppFontSize.normal);

      await tester.tap(find.byKey(const ValueKey('font-size-large')));
      await tester.pumpAndSettle();
      expect(storedSize, 'large');
      expect(_selectedSize(tester), AppFontSize.large);
      expect(_appearanceFontSize(tester), closeTo(normalFontSize * 1.15, 0.1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const ProviderScope(child: _FontOptionsApp()));
      await tester.pumpAndSettle();
      expect(_selectedSize(tester), AppFontSize.large);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fontPreferenceChannel, null);
    },
  );
}

AppFontSize _selectedSize(WidgetTester tester) => tester
    .widget<RadioGroup<AppFontSize>>(find.byType(RadioGroup<AppFontSize>))
    .groupValue!;

double _appearanceFontSize(WidgetTester tester) =>
    MediaQuery.textScalerOf(tester.element(find.text('Appearance'))).scale(10);

class _FontOptionsApp extends ConsumerWidget {
  const _FontOptionsApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(fontSizeControllerProvider);
    return MaterialApp(
      theme: AppTheme.forMode(HomeHubTheme.dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(size.scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SettingsScreen(),
    );
  }
}
