import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../models/event.dart';
import '../models/event_filter.dart';
import '../models/meeting.dart';
import '../state/events_controller.dart';
import '../widgets/d_filter_chip.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_status_chip.dart';
import 'event_detail_screen.dart';
import 'event_proposal_screen.dart';
import 'my_proposals_screen.dart';

/// Общие куски вкладок «Событий»: переходы, фильтр, строки заседаний.

void openEventDetail(BuildContext context, ClubEvent event) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => EventDetailScreen(event: event)),
  );
}

/// Форма предложения; после отправки — короткое подтверждение.
Future<void> openEventProposal(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => EventProposalScreen(initialDate: initialDate),
    ),
  );

  if (sent == true) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Предложение отправлено. Решение появится в «Мои предложения».',
        ),
      ),
    );
  }
}

final _dayMonth = DateFormat('d MMMM', 'ru_RU');
final _time = DateFormat('HH:mm');

String whenLabel(DateTime at) =>
    '${_dayMonth.format(at)} · ${_time.format(at)}';

String timeLabel(DateTime at) => _time.format(at);

/// Подпись к прошедшему заседанию: зелёная — был, остальное спокойно.
DStatusChip meetingMarkChip(Meeting m) {
  return switch (m.myStatus) {
    'present' => DStatusChip(m.markLabel, tone: DChipTone.green),
    'absent' => DStatusChip(m.markLabel, tone: DChipTone.muted),
    _ => DStatusChip(m.markLabel, tone: DChipTone.outline),
  };
}

/// Строка заседания: когда и где — или для кого, если место не задано.
DListRow meetingRow(
  Meeting m, {
  bool withDate = true,
  Widget? leading,
  Widget? trailing,
}) {
  final when = withDate ? whenLabel(m.scheduledAt) : timeLabel(m.scheduledAt);
  final where = m.place ?? m.audienceLabel;

  return DListRow(
    title: m.title,
    subtitle: where.isEmpty ? when : '$when · $where',
    leading: leading,
    trailing: trailing,
  );
}

/// Поиск и чипы над списком мероприятий. Варианты формата и темы
/// берутся из самого списка: предлагать то, чего нет, — вести в пустоту.
class EventsFilterBar extends StatelessWidget {
  const EventsFilterBar({
    super.key,
    required this.search,
    required this.events,
    required this.mineLabel,
  });

  final TextEditingController search;
  final List<ClubEvent> events;

  /// «Я записан» в афише, «Я был записан» в прошедших.
  final String mineLabel;

  static const _formatNames = {
    'offline': 'Очно',
    'online': 'Онлайн',
    'hybrid': 'Очно и онлайн',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();
    final filter = c.filter;

    final formats = EventFilter.formatsIn(events);
    // Выбранное не прячем, даже если в этом списке его нет, —
    // иначе фильтр не снять
    if (filter.format != null && !formats.containsKey(filter.format)) {
      formats[filter.format!] = _formatNames[filter.format] ?? filter.format!;
    }
    final topics = EventFilter.topicsIn(events);
    if (filter.topic != null && !topics.contains(filter.topic)) {
      topics.add(filter.topic!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: search,
          onChanged: (v) => c.setFilter(c.filter.withQuery(v)),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск по названию',
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: DColors.of(context).textSecondary,
            ),
          ),
        ),
        const SizedBox(height: DSpace.sm),
        // Высота 44 — вся полоса чипов остаётся нормальной целью для пальца
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              DFilterChip(
                label: mineLabel,
                selected: filter.mineOnly,
                onTap: () => c.setFilter(filter.toggleMine()),
              ),
              if (formats.length > 1 || filter.format != null)
                for (final MapEntry(:key, :value) in formats.entries)
                  DFilterChip(
                    label: value,
                    selected: filter.format == key,
                    onTap: () => c.setFilter(filter.toggleFormat(key)),
                  ),
              for (final topic in topics)
                DFilterChip(
                  label: topic,
                  selected: filter.topic == topic,
                  onTap: () => c.setFilter(filter.toggleTopic(topic)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Вход в предложения: своё мероприятие и судьба уже предложенных.
class EventsProposeBlock extends StatelessWidget {
  const EventsProposeBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DSectionLabel('Своё мероприятие'),
        const SizedBox(height: DSpace.sm),
        DRowsCard(
          children: [
            DListRow(
              title: 'Предложить мероприятие',
              subtitle: 'Организаторы посмотрят и опубликуют в афише',
              leading: Icon(Icons.add_circle_outline, color: c.accent),
              chevron: true,
              onTap: () => openEventProposal(context),
            ),
            DListRow(
              title: 'Мои предложения',
              leading: Icon(Icons.inbox_outlined, color: c.textSecondary),
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MyProposalsScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
