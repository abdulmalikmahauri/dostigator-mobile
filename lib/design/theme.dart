import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Тема приложения по спецификации: тёмно-зелёная база, один акцент,
/// Stolzl во всех ролях, спокойные анимации, никакого капса в контролах.
///
/// Светлая тема собирается тем же кодом от светлой палитры — различия
/// между темами живут только в [DColors], а не раскиданы по виджетам.
ThemeData buildDostigatorTheme({DColors palette = DColors.dark}) {
  final c = palette;
  final t = DText(c);

  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.accent,
    onPrimary: c.brandBlack,
    secondary: c.accent,
    onSecondary: c.brandBlack,
    surface: c.surface,
    onSurface: c.textPrimary,
    error: c.danger,
    onError: c.brandBlack,
    outline: c.cardBorder,
  );

  final controlText = TextStyle(
    fontFamily: DText.family,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [c],
    scaffoldBackgroundColor: c.background,
    fontFamily: DText.family,
    splashFactory: InkSparkle.splashFactory,

    textTheme: TextTheme(
      displayLarge: t.display,
      headlineLarge: t.h1,
      headlineMedium: t.h2,
      titleMedium: t.cardTitle,
      titleSmall: t.micro,
      bodyLarge: t.body,
      bodyMedium: t.bodyMuted,
      bodySmall: t.caption,
      labelLarge: controlText,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: c.isLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      titleTextStyle: t.h2,
      iconTheme: IconThemeData(color: c.textPrimary, size: 22),
    ),

    // Primary CTA: акцентный фон, тёмный текст, высота 54.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.brandBlack,
        disabledBackgroundColor: c.surface3,
        disabledForegroundColor: c.textTertiary,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DRadius.button),
        ),
        textStyle: controlText,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        side: BorderSide(color: c.accentBorder, width: 1),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DRadius.button),
        ),
        textStyle: const TextStyle(
          fontFamily: DText.family,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: const TextStyle(
          fontFamily: DText.family,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: TextStyle(color: c.textTertiary, fontSize: 15),
      labelStyle: TextStyle(color: c.textSecondary, fontSize: 15),
      helperStyle: t.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DRadius.input),
        borderSide: BorderSide(color: c.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DRadius.input),
        borderSide: BorderSide(color: c.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DRadius.input),
        borderSide: BorderSide(color: c.accent, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DRadius.input),
        borderSide: BorderSide(color: c.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DRadius.input),
        borderSide: BorderSide(color: c.danger, width: 1.2),
      ),
    ),

    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surface3,
      contentTextStyle: t.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DRadius.input),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: c.surface2,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: t.h2,
      contentTextStyle: t.bodyMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DRadius.card),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DRadius.cardLarge),
        ),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.surface3,
      circularTrackColor: c.surface3,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.brandBlack
            : c.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.accent : c.surface3,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(c.brandBlack),
      side: BorderSide(color: c.accentBorder, width: 1.4),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: c.textSecondary,
      textColor: c.textPrimary,
    ),
  );
}
