import 'package:flutter/material.dart';

import 'colors.dart';

/// Типографика по разделу 5 спецификации. Всё приложение — Stolzl.
///
/// Стили строятся от палитры текущей темы: `DText.of(context).body`.
/// Начертания и размеры одинаковы в обеих темах, меняется только цвет.
///
/// Капс запрещён в основном тексте: он живёт только в micro-подписях
/// вроде «ФОКУС НЕДЕЛИ», и там задаётся самим текстом, а не стилем.
@immutable
class DText {
  const DText(this._c);

  final DColors _c;

  static const family = 'Stolzl';

  static DText of(BuildContext context) => DText(DColors.of(context));

  /// Название раздела на вкладке: «Пульс», «Цели», «Группа».
  TextStyle get display => TextStyle(
    fontFamily: family,
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.02,
    letterSpacing: -0.5,
    color: _c.textPrimary,
  );

  TextStyle get h1 => TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: _c.textPrimary,
  );

  TextStyle get h2 => TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: _c.textPrimary,
  );

  TextStyle get cardTitle => TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: _c.textPrimary,
  );

  TextStyle get body => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: _c.textPrimary,
  );

  TextStyle get bodyMuted => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: _c.textSecondary,
  );

  TextStyle get caption => TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: _c.textSecondary,
  );

  /// Служебная зелёная подпись капсом: «ФОКУС НЕДЕЛИ», «МОИ ОБЯЗАТЕЛЬСТВА».
  TextStyle get micro => TextStyle(
    fontFamily: family,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0.8,
    color: _c.accent,
  );

  /// Крупные числа и KPI — полужирным, с табличными цифрами.
  TextStyle get kpi => TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: _c.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Число внутри кольца прогресса.
  TextStyle get ringValue => TextStyle(
    fontFamily: family,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: _c.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
