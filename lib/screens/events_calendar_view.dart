import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/club_time.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event.dart';
import '../models/meeting.dart';
import '../state/events_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_month_grid.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import 'events_parts.dart';

/// Календарь: месяц сеткой, под ней — что в выбранный день.
/// Без выбранного дня — весь месяц списком.
class EventsCalendarView extends StatefulWidget {
  const EventsCalendarView({super.key});

  @override
  State<EventsCalendarView> createState() => _EventsCalendarViewState();
}

class _EventsCalendarViewState extends State<EventsCalendarView> {
  int? _day;

  static final _monthTitle = DateFormat('LLLL y', 'ru_RU');
  static final _dayTitle = DateFormat('d MMMM, EEEE', 'ru_RU');

  void _shift(int months) {
    final c = context.read<EventsController>();
    final current = c.month ?? ClubTime.today();

    setState(() => _day = null);
    c.loadMonth(DateTime.utc(current.year, current.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();
    // «Сегодня» — по Москве: время мероприятий тоже московское
    final today = ClubTime.today();
    final month = c.month ?? DateTime.utc(today.year, today.month);
    final title = _monthTitle.format(month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Предыдущий месяц',
            ),
            Expanded(
              child: Text(
                title[0].toUpperCase() + title.substring(1),
                textAlign: TextAlign.center,
                style: DText.of(context).h2,
              ),
            ),
            IconButton(
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Следующий месяц',
            ),
          ],
        ),
        const SizedBox(height: DSpace.sm),
        DBrandCard(
          padding: const EdgeInsets.all(DSpace.sm),
          child: DMonthGrid(
            month: month,
            eventDays: c.monthEventDays,
            meetingDays: c.monthMeetingDays,
            selectedDay: _day,
            today: today,
            // Повторное нажатие на выбранный день возвращает весь месяц
            onSelect: (d) => setState(() => _day = _day == d ? null : d),
          ),
        ),
        const SizedBox(height: DSpace.sm),
        const DMonthLegend(),
        const SizedBox(height: DSpace.section),
        ..._agenda(context, c, month, today),
      ],
    );
  }

  List<Widget> _agenda(
    BuildContext context,
    EventsController c,
    DateTime month,
    DateTime today,
  ) {
    final empty = c.monthEvents.isEmpty && c.monthMeetings.isEmpty;

    if (c.monthLoading && empty) return const [DSkeletonCard(lines: 3)];

    if (c.monthError != null && empty) {
      return [
        DErrorState(
          message: 'Не удалось загрузить календарь',
          onRetry: () => c.loadMonth(month),
        ),
      ];
    }

    final day = _day;
    final events = [
      for (final e in c.monthEvents)
        if (day == null || e.startsAt.day == day) e,
    ];
    final meetings = [
      for (final m in c.monthMeetings)
        if (day == null || m.scheduledAt.day == day) m,
    ];
    final entries = <(DateTime, Widget)>[
      for (final e in events) (e.startsAt, _eventRow(context, e, day == null)),
      for (final m in meetings)
        (m.scheduledAt, _meetingRow(context, m, day == null)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final date = day == null
        ? null
        : DateTime.utc(month.year, month.month, day);

    return [
      DSectionLabel(date == null ? 'Весь месяц' : _dayTitle.format(date)),
      const SizedBox(height: DSpace.sm),
      if (entries.isNotEmpty)
        DRowsCard(children: [for (final (_, row) in entries) row])
      else if (date != null)
        DEmptyState(
          title: 'В этот день ничего не запланировано',
          // Предложить можно только на сегодня и дальше
          actionLabel: date.isBefore(today) ? null : 'Предложить мероприятие',
          onAction: () => openEventProposal(context, initialDate: date),
        )
      else
        const DEmptyState(title: 'В этом месяце пока ничего нет'),
    ];
  }

  Widget _eventRow(BuildContext context, ClubEvent listed, bool withDate) {
    // Месяц грузится реже, чем афиша: запись или отмену берём из свежей копии
    final e = context.read<EventsController>().find(listed.id) ?? listed;

    return DListRow(
      title: e.title,
      subtitle:
          '${withDate ? whenLabel(e.startsAt) : timeLabel(e.startsAt)} · '
          '${e.typeLabel}',
      leading: _Mark(color: DColors.of(context).accent),
      trailing: _chip(e),
      chevron: true,
      onTap: () => openEventDetail(context, e),
    );
  }

  /// У прошедшего — был ли я там, у будущего — записан ли.
  DStatusChip? _chip(ClubEvent e) {
    if (e.isPast) {
      if (e.checkedIn) return const DStatusChip('Был', tone: DChipTone.green);
      if (e.isRegistered) {
        return const DStatusChip('Не был', tone: DChipTone.muted);
      }
      return null;
    }

    return e.isRegistered
        ? const DStatusChip('Вы идёте', tone: DChipTone.green)
        : null;
  }

  Widget _meetingRow(BuildContext context, Meeting m, bool withDate) {
    return meetingRow(
      m,
      withDate: withDate,
      leading: _Mark(color: DColors.of(context).textSecondary),
    );
  }
}

/// Та же точка, что в сетке, — чтобы связь строки и дня читалась сразу.
class _Mark extends StatelessWidget {
  const _Mark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
