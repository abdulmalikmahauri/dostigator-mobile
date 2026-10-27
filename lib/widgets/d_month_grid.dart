import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Сетка месяца: неделя с понедельника, под числом — точки.
/// Зелёная — мероприятие, серая — заседание. Больше двух видов отметок
/// в клетку 44 пикселя не поместить так, чтобы их было видно.
class DMonthGrid extends StatelessWidget {
  const DMonthGrid({
    super.key,
    required this.month,
    required this.onSelect,
    this.eventDays = const {},
    this.meetingDays = const {},
    this.selectedDay,
    this.today,
  });

  /// Любой день нужного месяца — важны только год и месяц.
  final DateTime month;
  final ValueChanged<int> onSelect;
  final Set<int> eventDays;
  final Set<int> meetingDays;
  final int? selectedDay;

  /// Сегодня — чтобы выделить его и приглушить прошедшие дни.
  final DateTime? today;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  static final _dayName = DateFormat('d MMMM, EEEE', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final first = DateTime.utc(month.year, month.month);
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final rows = ((lead + days) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      w,
                      style: DText.of(
                        context,
                      ).caption.copyWith(color: c.textTertiary),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: DSpace.xs),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _cell(context, row * 7 + col - lead + 1, days)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int days) {
    if (day < 1 || day > days) return const SizedBox(height: 48);

    final date = DateTime(month.year, month.month, day);
    final t = today;
    final todayDate = t == null ? null : DateTime(t.year, t.month, t.day);

    final isToday = todayDate == date;

    return _DayCell(
      day: day,
      label: _label(date, day, isToday),
      hasEvent: eventDays.contains(day),
      hasMeeting: meetingDays.contains(day),
      selected: selectedDay == day,
      isToday: isToday,
      isPast: todayDate != null && date.isBefore(todayDate),
      onTap: () => onSelect(day),
    );
  }

  /// Для читалки экрана: «12 ноября, четверг: мероприятие, заседание».
  String _label(DateTime date, int day, bool isToday) {
    final day0 = _dayName.format(date);
    final name = isToday ? '$day0, сегодня' : day0;
    final parts = [
      if (eventDays.contains(day)) 'мероприятие',
      if (meetingDays.contains(day)) 'заседание',
    ];

    return parts.isEmpty ? name : '$name: ${parts.join(', ')}';
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.hasEvent,
    required this.hasMeeting,
    required this.selected,
    required this.isToday,
    required this.isPast,
    required this.onTap,
  });

  final int day;
  final String label;
  final bool hasEvent;
  final bool hasMeeting;
  final bool selected;
  final bool isToday;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final shape = BorderRadius.circular(12);

    final Color number;
    if (isToday) {
      number = c.accent;
    } else if (isPast) {
      number = c.textTertiary;
    } else {
      number = c.textPrimary;
    }

    // Нажатие объявлено на самом узле: дочерние узлы скрыты от читалки,
    // и без этого день был бы «кнопкой», которую нельзя нажать
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: selected ? c.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: shape,
            side: BorderSide(
              color: selected
                  ? c.accentBorder
                  : isToday
                  ? c.divider
                  : Colors.transparent,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            child: SizedBox(
              height: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: DText.of(context).body.copyWith(
                      fontSize: 14,
                      color: number,
                      fontWeight: isToday || selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasEvent) _Dot(color: c.accent),
                        if (hasEvent && hasMeeting) const SizedBox(width: 3),
                        if (hasMeeting) _Dot(color: c.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Пояснение к точкам под сеткой.
class DMonthLegend extends StatelessWidget {
  const DMonthLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final style = DText.of(context).caption;

    return ExcludeSemantics(
      child: Row(
        children: [
          _Dot(color: c.accent),
          const SizedBox(width: DSpace.xs),
          Text('Мероприятие', style: style),
          const SizedBox(width: DSpace.lg),
          _Dot(color: c.textSecondary),
          const SizedBox(width: DSpace.xs),
          Text('Заседание', style: style),
        ],
      ),
    );
  }
}
