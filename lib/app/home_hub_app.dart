import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import 'router.dart';

class HomeHubApp extends ConsumerWidget {
  const HomeHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'HomeHub',
      theme: AppTheme.forMode(HomeHubTheme.flower),
      darkTheme: AppTheme.forMode(HomeHubTheme.dark),
      themeMode: selectedTheme == HomeHubTheme.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
