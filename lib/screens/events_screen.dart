import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/club_time.dart';
import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event.dart';
import '../models/event_filter.dart';
import '../state/events_controller.dart';
import '../widgets/d_app_scaffold.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_qr_card.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_segmented.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import 'events_calendar_view.dart';
import 'events_parts.dart';
import 'events_past_view.dart';

enum _Tab { poster, calendar, past }

/// Вкладка «События»: афиша, календарь месяца и прошедшие —
/// переключателем вверху. Поиск и фильтр общие для афиши и прошедших.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  _Tab _tab = _Tab.poster;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<EventsController>().filter.query,
    );
    // Загружаем после первого кадра: load() дёргает notifyListeners,
    // а перестраивать дерево прямо из build нельзя
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EventsController>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _switch(_Tab tab) {
    setState(() => _tab = tab);
    final c = context.read<EventsController>();

    // Архив и календарь грузятся, только когда их открыли
    if (tab == _Tab.past && !c.pastLoaded && !c.pastLoading) c.loadPast();
    if (tab == _Tab.calendar && c.month == null) c.loadMonth(ClubTime.now());
  }

  Future<void> _refresh() {
    final c = context.read<EventsController>();

    return switch (_tab) {
      _Tab.poster => c.load(silent: true),
      _Tab.past => c.loadPast(),
      _Tab.calendar => c.loadMonth(c.month ?? ClubTime.now()),
    };
  }

  void _resetFilter() {
    _search.clear();
    context.read<EventsController>().setFilter(EventFilter.none);
  }

  @override
  Widget build(BuildContext context) {
    return DAppScaffold(
      title: 'События',
      subtitle: 'Афиша. Встречи. Нетворкинг.',
      onRefresh: _refresh,
      children: [
        DSegmented<_Tab>(
          segments: const [
            (_Tab.poster, 'Афиша'),
            (_Tab.calendar, 'Календарь'),
            (_Tab.past, 'Прошедшие'),
          ],
          selected: _tab,
          onChanged: _switch,
        ),
        const SizedBox(height: DSpace.section),
        switch (_tab) {
          _Tab.poster => _PosterView(search: _search, onReset: _resetFilter),
          _Tab.calendar => const EventsCalendarView(),
          _Tab.past => EventsPastView(search: _search, onReset: _resetFilter),
        },
      ],
    );
  }
}

/// Афиша: без фильтра — ближайшее событие, билет, остальное и заседания;
/// с фильтром — просто найденное.
class _PosterView extends StatelessWidget {
  const _PosterView({required this.search, required this.onReset});

  final TextEditingController search;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();

    // Сортируем сами: порядок на экране не должен зависеть от сервера
    final future = c.upcoming.where((e) => !e.isPast).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final ticket = c.nextRegistered;
    final hasAny = future.isNotEmpty || ticket != null || c.meetings.isNotEmpty;

    if (c.loading && !hasAny) {
      // Скелеты двух событий вместо полноэкранного спиннера
      return const Column(
        children: [
          DSkeletonCard(lines: 3),
          SizedBox(height: DSpace.section),
          DSkeletonCard(lines: 2),
        ],
      );
    }

    if (c.error != null && !hasAny) {
      return DErrorState(
        message: 'Не удалось загрузить события',
        onRetry: () => c.load(),
      );
    }

    final showFilter = future.isNotEmpty || !c.filter.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFilter) ...[
          EventsFilterBar(
            search: search,
            events: future,
            mineLabel: 'Я записан',
          ),
          const SizedBox(height: DSpace.section),
        ],
        if (c.filter.isEmpty)
          ..._overview(future, ticket, c)
        else
          ..._found(c.filter.apply(future)),
        const SizedBox(height: DSpace.section),
        const EventsProposeBlock(),
      ],
    );
  }

  List<Widget> _overview(
    List<ClubEvent> future,
    ClubEvent? ticket,
    EventsController c,
  ) {
    return [
      if (future.isEmpty)
        const DEmptyState(title: 'Ближайших событий пока нет')
      else ...[
        const DSectionLabel('Ближайшее событие'),
        const SizedBox(height: DSpace.sm),
        _FeaturedCard(event: future.first),
      ],

      // Билет показываем даже при пустой афише: регистрация уже есть,
      // и билет важнее пустой ленты
      if (ticket != null) ...[
        const SizedBox(height: DSpace.section),
        const DSectionLabel('Мой билет'),
        const SizedBox(height: DSpace.sm),
        _TicketCard(event: ticket),
      ],

      if (future.length > 1) ...[
        const SizedBox(height: DSpace.section),
        const DSectionLabel('Другие события'),
        const SizedBox(height: DSpace.sm),
        _EventRows(events: future.skip(1).toList()),
      ],

      if (c.meetings.isNotEmpty) ...[
        const SizedBox(height: DSpace.section),
        const DSectionLabel('Заседания'),
        const SizedBox(height: DSpace.sm),
        // Ближайшие три: дальше — в календаре, где видно весь месяц
        DRowsCard(
          children: [for (final m in c.meetings.take(3)) meetingRow(m)],
        ),
      ],
    ];
  }

  List<Widget> _found(List<ClubEvent> found) {
    if (found.isEmpty) {
      return [
        DEmptyState(
          title: 'Ничего не нашлось',
          message: 'Попробуйте другое слово или снимите фильтр.',
          actionLabel: 'Сбросить фильтр',
          onAction: onReset,
        ),
      ];
    }

    return [
      DSectionLabel(
        'Найдено: ${Fmt.plural(found.length, 'событие', 'события', 'событий')}',
      ),
      const SizedBox(height: DSpace.sm),
      _EventRows(events: found),
    ];
  }
}

/// Строки афиши со статусом записи.
class _EventRows extends StatelessWidget {
  const _EventRows({required this.events});

  final List<ClubEvent> events;

  @override
  Widget build(BuildContext context) {
    return DRowsCard(
      children: [
        for (final e in events)
          DListRow(
            title: e.title,
            subtitle: _subtitle(e),
            trailing: _chip(e),
            chevron: true,
            onTap: () => openEventDetail(context, e),
          ),
      ],
    );
  }

  /// Формат пишем, только когда он не «очно»: очно — обычный случай.
  String _subtitle(ClubEvent e) {
    final when = whenLabel(e.startsAt);
    final online = e.format != null && e.format != 'offline';

    return online && e.formatLabel != null ? '$when · ${e.formatLabel}' : when;
  }

  DStatusChip _chip(ClubEvent e) {
    // «Вы идёте» важнее прочих статусов: своя запись — главное
    if (e.isRegistered) {
      return const DStatusChip('Вы идёте', tone: DChipTone.green);
    }
    if (e.isFull) return const DStatusChip('Мест нет', tone: DChipTone.muted);
    if (e.isRunningOut) {
      return const DStatusChip('Мест мало', tone: DChipTone.yellow);
    }
    if (!e.isAvailable) {
      return const DStatusChip('Только клуб', tone: DChipTone.outline);
    }
    return const DStatusChip('Открыта запись', tone: DChipTone.greenOutline);
  }
}

/// Большая карточка ближайшего события: факты и один CTA по состоянию записи.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EventsController>();
    final busy = c.busyEventId == event.id;
    final seats = event.seatsSummary;
    final online = event.format != null && event.format != 'offline';

    return DBrandCard(
      background: DColors.of(context).surface2,
      radius: DRadius.cardLarge,
      onTap: () => openEventDetail(context, event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.typeLabel, style: DText.of(context).caption),
          const SizedBox(height: DSpace.xs),
          Text(event.title, style: DText.of(context).h2),
          const SizedBox(height: DSpace.md),
          _InfoRow(
            icon: Icons.event_outlined,
            text: '${Fmt.date(event.startsAt)} · ${_timeRange(event)}',
          ),
          if (online && event.formatLabel != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(icon: Icons.videocam_outlined, text: event.formatLabel!),
          ],
          if (event.place != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(icon: Icons.place_outlined, text: event.place!),
          ],
          if (seats != null) ...[
            const SizedBox(height: DSpace.xs),
            _InfoRow(
              icon: Icons.people_outline,
              text: seats,
              // Жёлтый только как предупреждение: места заканчиваются
              color: event.isRunningOut ? DColors.of(context).warning : null,
            ),
          ],
          const SizedBox(height: DSpace.lg),
          _cta(context, busy),
        ],
      ),
    );
  }

  Widget _cta(BuildContext context, bool busy) {
    if (event.isRegistered) {
      return Row(
        children: [
          const DStatusChip('Вы идёте', tone: DChipTone.green),
          const SizedBox(width: DSpace.md),
          Expanded(
            child: OutlinedButton(
              onPressed: () => openEventDetail(context, event),
              child: const Text('Открыть билет'),
            ),
          ),
        ],
      );
    }

    if (!event.isAvailable) {
      // Закрытое событие не скрываем — пользователь должен видеть,
      // что функция существует, но требует другого уровня
      return const Align(
        alignment: Alignment.centerLeft,
        child: DStatusChip('Только для бизнес-клуба', tone: DChipTone.outline),
      );
    }

    if (event.isFull) {
      // onPressed == null — кнопка выключена стилем темы
      return const DPrimaryButton(label: 'Мест нет');
    }

    return DPrimaryButton(
      label: 'Записаться',
      loading: busy,
      onPressed: () => _register(context),
    );
  }

  Future<void> _register(BuildContext context) async {
    final c = context.read<EventsController>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await c.register(event.id);

    if (error != null) {
      // Типичный случай — 422 «мест больше нет»: показываем причину
      // и перечитываем афишу, чтобы места стали актуальными
      messenger.showSnackBar(SnackBar(content: Text(error)));
      await c.load(silent: true);
    }
  }

  String _timeRange(ClubEvent e) {
    final f = DateFormat('HH:mm');
    final start = f.format(e.startsAt);
    return e.endsAt == null ? start : '$start–${f.format(e.endsAt!)}';
  }
}

/// Компактная карточка билета на ближайшую регистрацию: мини-QR и переход
/// к полному билету на экране события.
class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.event});

  final ClubEvent event;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      onTap: () => openEventDetail(context, event),
      child: Row(
        children: [
          // Билет выдаёт сервер вместе с регистрацией; локальные коды
          // не генерируем — без ticket QR просто не рисуем
          if (event.ticket != null) ...[
            DQrCard(data: event.ticket!, size: 120),
            const SizedBox(width: DSpace.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: DText.of(context).cardTitle),
                const SizedBox(height: DSpace.xs),
                Text(
                  '${Fmt.date(event.startsAt)} · '
                  '${DateFormat('HH:mm').format(event.startsAt)}',
                  style: DText.of(context).caption,
                ),
                const SizedBox(height: DSpace.sm),
                Text('Покажите QR на входе', style: DText.of(context).caption),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: DColors.of(context).textTertiary,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? DColors.of(context).textTertiary),
        const SizedBox(width: DSpace.sm),
        Expanded(
          child: Text(
            text,
            style: color == null
                ? DText.of(context).bodyMuted
                : DText.of(context).body.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
