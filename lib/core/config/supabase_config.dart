import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseConfiguredProvider = Provider<bool>(
  (ref) => SupabaseConfig.isReady,
);

abstract final class SupabaseConfig {
  static bool _initializationFailed = false;

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
  static bool get isReady => isConfigured && !_initializationFailed;

  static Future<void> initializeIfConfigured() async {
    if (!isConfigured) return;
    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
    } catch (_) {
      _initializationFailed = true;
    }
  }
}
