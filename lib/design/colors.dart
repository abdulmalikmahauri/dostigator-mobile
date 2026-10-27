import 'package:flutter/material.dart';

/// Цветовые токены из UI/UX-спецификации (раздел 4).
///
/// Палитра живёт в теме как [ThemeExtension]: виджеты берут цвета через
/// [DColors.of], и при переключении темы перерисовываются сами. Тёмная
/// палитра — фирменная и основная; светлая выведена из неё, а не
/// придумана заново: та же база, тот же единственный акцент.
///
/// Жёлтый только для предупреждений, красный только для ошибок.
@immutable
class DColors extends ThemeExtension<DColors> {
  const DColors({
    required this.brightness,
    required this.background,
    required this.brandBlack,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.warning,
    required this.danger,
    required this.patternStroke,
  });

  final Brightness brightness;

  /// Базовый фон приложения.
  final Color background;

  /// Почти чёрный фирменный цвет — текст на акцентных заливках.
  final Color brandBlack;

  /// Карточки.
  final Color surface;
  final Color surface2;
  final Color surface3;

  /// Главный акцент.
  final Color accent;

  /// Акцентные прозрачности.
  final Color accentSoft;
  final Color accentBorder;

  /// Контур карточек — из раздела 6 спецификации.
  final Color cardBorder;

  /// Текст.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Разделители.
  final Color divider;

  /// Состояния.
  final Color warning;
  final Color danger;

  /// Штрих фирменного паттерна фона.
  final Color patternStroke;

  bool get isLight => brightness == Brightness.light;

  /// Фирменная тёмная палитра — значения из брендбука, не «осовременивать».
  static const dark = DColors(
    brightness: Brightness.dark,
    background: Color(0xFF040E08),
    brandBlack: Color(0xFF020304),
    surface: Color(0xFF091C0E),
    surface2: Color(0xFF0D2415),
    surface3: Color(0xFF122D1C),
    accent: Color(0xFF00FE7E),
    accentSoft: Color(0x2100FE7E),
    accentBorder: Color(0x3800FE7E),
    cardBorder: Color(0x2900FE7E),
    textPrimary: Color(0xFFF0F7F2),
    textSecondary: Color(0x99F0F7F2),
    textTertiary: Color(0x52F0F7F2),
    divider: Color(0x12FFFFFF),
    warning: Color(0xFFFFC24D),
    danger: Color(0xFFFF8E8E),
    // Цвет взят из pattern 1 брендбука
    patternStroke: Color(0xFF072A1C),
  );

  /// Светлая палитра. Акцент тот же зелёный, но глубже: неоновый #00FE7E
  /// на белом нечитаем, а #00B85C — тот оттенок, которым уже покрашена
  /// админка. Поверхности держат лёгкий зелёный подтон, чтобы приложение
  /// и днём оставалось «Достигатором», а не серым дашбордом.
  static const light = DColors(
    brightness: Brightness.light,
    background: Color(0xFFF3F7F4),
    brandBlack: Color(0xFF020304),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEAF2EC),
    surface3: Color(0xFFDCE9E0),
    accent: Color(0xFF00B85C),
    accentSoft: Color(0x2400B85C),
    accentBorder: Color(0x5900B85C),
    cardBorder: Color(0x3800B85C),
    textPrimary: Color(0xFF0A1A10),
    textSecondary: Color(0x9E0A1A10),
    textTertiary: Color(0x5C0A1A10),
    divider: Color(0x14000000),
    warning: Color(0xFFA86A00),
    danger: Color(0xFFC62828),
    patternStroke: Color(0xFFDCEBE0),
  );

  /// Палитра текущей темы. Вне MaterialApp (тесты отдельных виджетов,
  /// сплэш до старта) — фирменная тёмная.
  static DColors of(BuildContext context) =>
      Theme.of(context).extension<DColors>() ?? dark;

  @override
  DColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? brandBlack,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? accent,
    Color? accentSoft,
    Color? accentBorder,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? warning,
    Color? danger,
    Color? patternStroke,
  }) {
    return DColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      brandBlack: brandBlack ?? this.brandBlack,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentBorder: accentBorder ?? this.accentBorder,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      patternStroke: patternStroke ?? this.patternStroke,
    );
  }

  @override
  DColors lerp(ThemeExtension<DColors>? other, double t) {
    if (other is! DColors) return this;

    // Яркость не интерполируется: переключаем её на середине анимации,
    // чтобы системные элементы не застревали между темами
    return DColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      brandBlack: Color.lerp(brandBlack, other.brandBlack, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentBorder: Color.lerp(accentBorder, other.accentBorder, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      patternStroke: Color.lerp(patternStroke, other.patternStroke, t)!,
    );
  }
}
