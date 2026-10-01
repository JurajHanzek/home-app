import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

final themeControllerProvider = NotifierProvider<ThemeController, HomeHubTheme>(
  ThemeController.new,
);

class ThemeController extends Notifier<HomeHubTheme> {
  @override
  HomeHubTheme build() => HomeHubTheme.dark;

  void toggle() {
    state = state == HomeHubTheme.dark
        ? HomeHubTheme.flower
        : HomeHubTheme.dark;
  }
}
