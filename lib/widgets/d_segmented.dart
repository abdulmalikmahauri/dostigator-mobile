import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Переключатель разделов одного экрана: «Афиша · Календарь · Прошедшие».
/// Выбранный сегмент выделен нейтральной поверхностью, а не зелёным:
/// зелёный в интерфейсе означает действие или выбранный фильтр,
/// а здесь просто «где я сейчас».
class DSegmented<T> extends StatelessWidget {
  const DSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(DRadius.chip),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: _Segment(
                label: label,
                selected: value == selected,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
    final shape = BorderRadius.circular(DRadius.chip);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.surface3 : Colors.transparent,
        borderRadius: shape,
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: shape,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DText.of(context).body.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
