import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Нижняя навигация (раздел 9): пять вкладок, активная — зелёная
/// иконка и текст с точкой, неактивные — приглушённые, без плашек.
class DBottomNav extends StatelessWidget {
  const DBottomNav({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.show_chart, 'Пульс'),
    (Icons.checklist, 'Планер'),
    (Icons.people_outline, 'Группа'),
    (Icons.calendar_today_outlined, 'События'),
    (Icons.shield_outlined, 'Клуб'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DColors.of(context).background,
        border: Border(top: BorderSide(color: DColors.of(context).divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    active: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? DColors.of(context).accent
        : DColors.of(context).textTertiary;

    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: DColors.of(context).accentSoft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Stolzl',
                fontSize: 11,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            // Точка-индикатор активной вкладки
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: DColors.of(context).accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
