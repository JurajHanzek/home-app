import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flower_theme.dart';

enum HomeHubTheme { dark, flower }

enum AppFontSize {
  small('Small', 0.90),
  normal('Normal', 1.0),
  large('Large', 1.15);

  const AppFontSize(this.label, this.scale);
  final String label;
  final double scale;
}

@immutable
class TaskStatusColors extends ThemeExtension<TaskStatusColors> {
  const TaskStatusColors({
    required this.toDo,
    required this.inProgress,
    required this.done,
  });

  final Color toDo;
  final Color inProgress;
  final Color done;

  @override
  TaskStatusColors copyWith({Color? toDo, Color? inProgress, Color? done}) =>
      TaskStatusColors(
        toDo: toDo ?? this.toDo,
        inProgress: inProgress ?? this.inProgress,
        done: done ?? this.done,
      );

  @override
  TaskStatusColors lerp(ThemeExtension<TaskStatusColors>? other, double t) {
    if (other is! TaskStatusColors) return this;
    return TaskStatusColors(
      toDo: Color.lerp(toDo, other.toDo, t)!,
      inProgress: Color.lerp(inProgress, other.inProgress, t)!,
      done: Color.lerp(done, other.done, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData forMode(HomeHubTheme mode) {
    final isDark = mode == HomeHubTheme.dark;
    final scheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: const Color(0xFFB5C7E8),
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFFB5C7E8),
            onPrimary: const Color(0xFF101723),
            primaryContainer: const Color(0xFF202A3A),
            onPrimaryContainer: const Color(0xFFDEE8FA),
            secondary: const Color(0xFFBEC5D0),
            onSecondary: const Color(0xFF15191F),
            secondaryContainer: const Color(0xFF232830),
            onSecondaryContainer: const Color(0xFFE2E7EF),
            tertiary: const Color(0xFFC8BEDC),
            tertiaryContainer: const Color(0xFF2A2435),
            onTertiaryContainer: const Color(0xFFECE2FA),
            surface: Colors.black,
            surfaceDim: Colors.black,
            surfaceBright: const Color(0xFF292929),
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: const Color(0xFF101010),
            surfaceContainer: const Color(0xFF161616),
            surfaceContainerHigh: const Color(0xFF1D1D1D),
            surfaceContainerHighest: const Color(0xFF252525),
            onSurface: const Color(0xFFF1F1F3),
            onSurfaceVariant: const Color(0xFFA5A7AD),
            outline: const Color(0xFF62646B),
            outlineVariant: const Color(0xFF2A2B2F),
            surfaceTint: Colors.transparent,
            inverseSurface: const Color(0xFFE7E7EA),
            onInverseSurface: const Color(0xFF171719),
            inversePrimary: const Color(0xFF385478),
          )
        : FlowerTheme.colors;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? Colors.black : const Color(0xFFF7F4E9),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isDark ? scheme.surfaceContainerLow : const Color(0xFFFFFEF9),
        margin: EdgeInsets.zero,
      ),
      extensions: [
        TaskStatusColors(
          toDo: isDark ? const Color(0xFF78B7FF) : const Color(0xFF125FB5),
          inProgress: isDark
              ? const Color(0xFFFFD447)
              : const Color(0xFF956000),
          done: isDark ? const Color(0xFFBAC2CD) : const Color(0xFF4B5663),
        ),
      ],
    );
    if (!isDark) return FlowerTheme.apply(base);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: controlShape,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: controlShape),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shape,
        extendedTextStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: controlShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: controlShape.copyWith(
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
