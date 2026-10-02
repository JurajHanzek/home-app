import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/font_size_controller.dart';
import '../core/theme/flower_backdrop.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/presentation/auth_screens.dart';
import 'router.dart';

class HomeHubApp extends ConsumerWidget {
  const HomeHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(themeControllerProvider);
    final fontSize = ref.watch(fontSizeControllerProvider);
    final theme = AppTheme.forMode(HomeHubTheme.flower);
    final darkTheme = AppTheme.forMode(HomeHubTheme.dark);
    Widget scaleText(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(fontSize.scale)),
      child: selectedTheme == HomeHubTheme.flower
          ? FlowerBackdrop(child: child ?? const SizedBox.shrink())
          : child ?? const SizedBox.shrink(),
    );
    final themeMode = selectedTheme == HomeHubTheme.dark
        ? ThemeMode.dark
        : ThemeMode.light;

    if (!ref.watch(supabaseConfiguredProvider)) {
      return MaterialApp(
        title: 'HomeHub',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        builder: scaleText,
        home: const SupabaseSetupScreen(),
      );
    }

    return MaterialApp.router(
      title: 'HomeHub',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: scaleText,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
