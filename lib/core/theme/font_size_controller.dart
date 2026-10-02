import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

const fontPreferenceChannel = MethodChannel('app.homehub/preferences');

final fontSizeControllerProvider =
    NotifierProvider<FontSizeController, AppFontSize>(FontSizeController.new);

class FontSizeController extends Notifier<AppFontSize> {
  bool _changedByUser = false;

  @override
  AppFontSize build() {
    _restore();
    return AppFontSize.normal;
  }

  Future<void> _restore() async {
    try {
      final stored = await fontPreferenceChannel.invokeMethod<String>(
        'getFontSize',
      );
      if (_changedByUser || stored == null) return;
      state = AppFontSize.values.firstWhere(
        (size) => size.name == stored,
        orElse: () => AppFontSize.normal,
      );
    } on MissingPluginException {
      // Non-Android test hosts and preview environments use the default.
    } on PlatformException {
      // Keep the app usable if the local preference store is unavailable.
    }
  }

  Future<void> setSize(AppFontSize size) async {
    _changedByUser = true;
    state = size;
    try {
      await fontPreferenceChannel.invokeMethod<void>('setFontSize', size.name);
    } on MissingPluginException {
      // The persisted setting is provided by the Android host application.
    } on PlatformException {
      // Keep the selected size for this session if persistence fails.
    }
  }
}
