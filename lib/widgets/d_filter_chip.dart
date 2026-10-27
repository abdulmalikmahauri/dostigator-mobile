import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Чип фильтра: ниша в каталоге, формат или тема в афише.
/// Повторное нажатие на выбранный обычно снимает фильтр — решает экран.
class DFilterChip extends StatelessWidget {
  const DFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: DSpace.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DRadius.chip),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? c.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(DRadius.chip),
              border: Border.all(color: selected ? c.accentBorder : c.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Выбор виден не только цветом — раздел 35 спецификации
                if (selected) ...[
                  Icon(Icons.check, size: 14, color: c.accent),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: DText.of(context).caption.copyWith(
                    color: selected ? c.accent : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
