import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class FlowerTheme {
  static final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF456344),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF285D37),
        onPrimary: const Color(0xFFFFFEF5),
        primaryContainer: const Color(0xFFC5DEAB),
        onPrimaryContainer: const Color(0xFF253E28),
        secondary: const Color(0xFF627548),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFD2E3B5),
        onSecondaryContainer: const Color(0xFF354626),
        tertiary: const Color(0xFF79617E),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFEFE3EF),
        onTertiaryContainer: const Color(0xFF503953),
        surface: const Color(0xFFF7F8EE),
        surfaceDim: const Color(0xFFE2EADC),
        surfaceBright: const Color(0xFFFFFFF8),
        surfaceContainerLowest: const Color(0xFFFFFFFA),
        surfaceContainerLow: const Color(0xFFFAFBF2),
        surfaceContainer: const Color(0xFFF0F4E7),
        surfaceContainerHigh: const Color(0xFFE7EEDC),
        surfaceContainerHighest: const Color(0xFFDCE6D3),
        onSurface: const Color(0xFF25362B),
        onSurfaceVariant: const Color(0xFF596557),
        outline: const Color(0xFF7A8774),
        outlineVariant: const Color(0xFFB1C5A3),
        surfaceTint: Colors.transparent,
        inverseSurface: const Color(0xFF2D4032),
        onInverseSurface: const Color(0xFFF4F6E9),
        inversePrimary: const Color(0xFFBED5AA),
      );

  static ThemeData apply(ThemeData base) {
    final c = colors;
    final petal = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    final control = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      // The app-level botanical canvas supplies the opaque background.
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: const Color(0xF0E9F2E1),
        foregroundColor: c.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFF7F8EE),
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: c.surfaceContainerLowest,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: petal,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: petal.copyWith(side: BorderSide(color: c.outlineVariant)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceContainerLow,
        modalBackgroundColor: c.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.primary
                : c.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.primary
                : c.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surfaceContainerLow,
          foregroundColor: c.primary,
          side: BorderSide(color: c.outlineVariant),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        highlightElevation: 3,
        shape: const StadiumBorder(),
        extendedTextStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.surfaceContainerLow,
        selectedColor: c.secondaryContainer,
        side: BorderSide(color: c.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: c.onSecondaryContainer,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: const Color(0xFFF0F5EC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: c.onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: control.copyWith(side: BorderSide(color: c.outlineVariant)),
      ),
      dividerTheme: DividerThemeData(
        color: c.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: c.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
