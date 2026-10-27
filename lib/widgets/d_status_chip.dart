import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';

/// Тональности статусов из раздела 10.5 спецификации.
/// Жёлтый — только «требует внимания», красный чипам не положен вовсе.
enum DChipTone {
  /// Выполнено, есть места, цель взята.
  green,

  /// В процессе, нужна помощь, мест мало.
  yellow,

  /// Запланировано, нейтральная пометка.
  muted,

  /// «Только клуб» и подобные ограничения — контур без заливки.
  outline,

  /// «Есть места» — зелёный контур без заливки.
  greenOutline,
}

class DStatusChip extends StatelessWidget {
  const DStatusChip(this.label, {super.key, this.tone = DChipTone.muted});

  final String label;
  final DChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final (Color fg, Color bg, Color border) = switch (tone) {
      DChipTone.green => (c.accent, c.accentSoft, Colors.transparent),
      DChipTone.yellow => (
        c.warning,
        c.warning.withValues(alpha: 0.14),
        Colors.transparent,
      ),
      // Нейтральная плашка — лёгкий оттенок цвета текста, чтобы на светлом
      // фоне она не пропадала, а на тёмном оставалась прежней
      DChipTone.muted => (
        c.textSecondary,
        c.textPrimary.withValues(alpha: 0.06),
        Colors.transparent,
      ),
      DChipTone.outline => (c.textSecondary, Colors.transparent, c.divider),
      DChipTone.greenOutline => (c.accent, Colors.transparent, c.accentBorder),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DRadius.chip),
        border: Border.all(
          color: border,
          width: border == Colors.transparent ? 0 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Stolzl',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.2,
          color: fg,
        ),
      ),
    );
  }
}
