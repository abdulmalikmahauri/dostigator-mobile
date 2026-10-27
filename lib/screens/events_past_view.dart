import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event.dart';
import '../models/meeting.dart';
import '../state/events_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import 'events_parts.dart';

/// Прошедшие: мероприятия клуба с фото и моими отметками,
/// мои заседания и посещаемость за всё время.
class EventsPastView extends StatelessWidget {
  const EventsPastView({
    super.key,
    required this.search,
    required this.onReset,
  });

  final TextEditingController search;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();

    if (c.pastLoading && !c.pastLoaded) {
      return const Column(
        children: [
          DSkeletonCard(lines: 3),
          SizedBox(height: DSpace.section),
          DSkeletonCard(lines: 3),
        ],
      );
    }

    if (c.pastError != null && !c.pastLoaded) {
      return DErrorState(
        message: 'Не удалось загрузить прошедшие',
        onRetry: c.loadPast,
      );
    }

    if (c.past.isEmpty && c.pastMeetings.isEmpty) {
      return const DEmptyState(
        title: 'Прошедших мероприятий пока нет',
        message: 'Здесь появятся встречи, на которых вы были, и фото с них.',
      );
    }

    // Свежие сверху: чаще всего ищут то, что было на днях
    final events = c.filter.apply(c.past).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.attendance.held > 0) ...[
          _AttendanceCard(attendance: c.attendance),
          const SizedBox(height: DSpace.section),
        ],
        if (c.past.isNotEmpty) ...[
          EventsFilterBar(
            search: search,
            events: c.past,
            mineLabel: 'Я был записан',
          ),
          const SizedBox(height: DSpace.section),
          if (events.isEmpty)
            DEmptyState(
              title: 'Ничего не нашлось',
              message: 'Попробуйте другое слово или снимите фильтр.',
              actionLabel: 'Сбросить фильтр',
              onAction: onReset,
            )
          else ...[
            const DSectionLabel('Мероприятия'),
            const SizedBox(height: DSpace.sm),
            DRowsCard(
              children: [
                for (final e in events)
                  DListRow(
                    title: e.title,
                    subtitle: '${Fmt.date(e.startsAt)} · ${e.typeLabel}',
                    trailing: _trailing(e),
                    chevron: true,
                    onTap: () => openEventDetail(context, e),
                  ),
              ],
            ),
          ],
        ],
        if (c.pastMeetings.isNotEmpty) ...[
          if (c.past.isNotEmpty) const SizedBox(height: DSpace.section),
          const DSectionLabel('Заседания'),
          const SizedBox(height: DSpace.sm),
          DRowsCard(
            children: [
              for (final m in c.pastMeetings)
                meetingRow(m, trailing: meetingMarkChip(m)),
            ],
          ),
        ],
      ],
    );
  }

  /// Своя отметка важнее фото: «был ли я там» — первое, что ищут глазами.
  Widget? _trailing(ClubEvent e) {
    if (e.checkedIn) return const DStatusChip('Был', tone: DChipTone.green);
    if (e.isRegistered) {
      return const DStatusChip('Не был', tone: DChipTone.muted);
    }
    if (e.photosCount > 0) {
      return DStatusChip('${e.photosCount} фото', tone: DChipTone.outline);
    }
    return null;
  }
}

/// Посещаемость заседаний — одной цифрой, без оценок и процентов.
class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.attendance});

  final MeetingAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);

    return DBrandCard(
      background: DColors.of(context).surface2,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Посещаемость заседаний', style: t.caption),
                const SizedBox(height: DSpace.xs),
                Text(
                  'Вы были на ${Fmt.plural(attendance.present, 'заседании', 'заседаниях', 'заседаниях')} '
                  'из ${attendance.held} отмеченных',
                  style: t.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(width: DSpace.md),
          Text('${attendance.present} из ${attendance.held}', style: t.kpi),
        ],
      ),
    );
  }
}
