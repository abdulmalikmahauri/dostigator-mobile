import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/mastermind.dart';
import '../state/mastermind_controller.dart';
import '../widgets/d_app_scaffold.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import 'protocol_screen.dart';

/// Вкладка «Группа» (раздел 16): ближайший мастермайнд, участники,
/// повестка, мои обязательства и прошлый протокол — в порядке приоритета
/// информации (раздел 46: мастермайнд выше обязательств и всего прочего).
///
/// Privacy (раздел 29): обычный участник видит только свою строку повестки
/// и обезличенную сводку; полный список с talking points — только куратор.
class MastermindScreen extends StatefulWidget {
  const MastermindScreen({super.key});

  @override
  State<MastermindScreen> createState() => _MastermindScreenState();
}

class _MastermindScreenState extends State<MastermindScreen> {
  @override
  void initState() {
    super.initState();
    // После первого кадра: load() зовёт notifyListeners, а уведомлять
    // слушателей во время build запрещено фреймворком.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MastermindController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MastermindController>();
    final sections = _sections(c);

    return DAppScaffold(
      title: 'Группа',
      subtitle: 'Мастермайнд. Ответственность. Рост.',
      onRefresh: () => c.load(silent: true),
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: DSpace.section),
          section,
        ],
      ],
    );
  }

  List<Widget> _sections(MastermindController c) {
    // Скелеты вместо полноэкранного спиннера (раздел 33)
    if (c.loading && c.group == null) {
      return const [
        DSkeletonCard(lines: 3),
        DSkeletonCard(lines: 2),
        DSkeletonCard(lines: 2),
      ];
    }

    if (c.error != null && c.group == null) {
      return [DErrorState(message: c.error!, onRetry: () => c.load())];
    }

    final group = c.group;

    if (group == null) {
      // Причина от сервера точнее (нет распределения / не тот уровень),
      // текст раздела 31 — запасной вариант
      return [
        DEmptyState(
          title: 'Группа пока не назначена',
          message:
              c.unavailableReason ?? 'Организатор добавит вас в мастермайнд.',
        ),
      ];
    }

    // Group Selector (блок 1 раздела 16) не показываем: API отдаёт
    // одну текущую группу, а для единственной группы селектор не нужен.
    return [
      _NextSessionCard(group: group),
      _MembersCard(members: group.members),
      if (c.nextSession != null)
        _AgendaCard(session: c.nextSession!, group: group),
      if (c.myCommitments.isNotEmpty) _CommitmentsCard(items: c.myCommitments),
      if (group.lastSession != null) _ProtocolCard(session: group.lastSession!),
    ];
  }
}

String _time(DateTime d) => DateFormat('HH:mm').format(d);

// ---- Блок 2 раздела 16. Ближайший мастермайнд ---------------------------

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.group});

  final MastermindGroup group;

  @override
  Widget build(BuildContext context) {
    final session = group.nextSession;

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Ближайший мастермайнд'),
          const SizedBox(height: DSpace.sm),
          if (session == null)
            Text(
              'Встреча пока не назначена',
              style: DText.of(context).bodyMuted,
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // TODO(api): темы встречи в API нет — заголовок карточки
                  // собираем из даты и времени.
                  child: Text(
                    '${Fmt.date(session.scheduledAt)} · ${_time(session.scheduledAt)}',
                    style: DText.of(context).cardTitle,
                  ),
                ),
                const SizedBox(width: DSpace.sm),
                if (session.hasAgenda)
                  const DStatusChip(
                    'Повестка готова',
                    tone: DChipTone.greenOutline,
                  )
                else
                  const DStatusChip('Запланирована'),
              ],
            ),
            if (session.place != null) ...[
              const SizedBox(height: DSpace.xs),
              Text(session.place!, style: DText.of(context).caption),
            ],
          ],
          const SizedBox(height: DSpace.md),
          Text(
            [
              Fmt.plural(
                group.membersCount,
                'участник',
                'участника',
                'участников',
              ),
              if (group.curatorName != null && !group.isCurator)
                'ведёт ${group.curatorName}',
              if (group.isCurator) 'вы куратор',
            ].join(' · '),
            style: DText.of(context).caption,
          ),
          // TODO(api): номера встречи в API нет — группа отдаёт только
          // последнюю сессию, полного счёта прошедших нет. Номер опускаем.
        ],
      ),
    );
  }
}

// ---- Блок 3 раздела 16. Участники группы ---------------------------------

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.members});

  final List<GroupMember> members;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Участники группы'),
          const SizedBox(height: DSpace.xs),
          for (final (i, m) in members.indexed) ...[
            if (i > 0) Divider(color: DColors.of(context).divider, height: 1),
            DListRow(
              leading: DUserAvatar(name: m.name),
              title: m.isMe ? '${m.name} — это вы' : m.name,
              subtitle: m.business,
              trailing: _chip(m),
            ),
          ],
        ],
      ),
    );
  }

  /// Чип строится только из public_status: это единственная категория,
  /// которую сервер разрешил показывать всей группе. null — без чипа.
  Widget? _chip(GroupMember m) {
    final tone = switch (m.publicStatus) {
      'needs_help' => DChipTone.yellow,
      'no_checkin' => DChipTone.muted,
      'working' => DChipTone.muted,
      'on_focus' => DChipTone.greenOutline,
      'achieved' => DChipTone.green,
      _ => null,
    };

    if (tone == null) return null;

    final fallback = switch (m.publicStatus) {
      'needs_help' => 'Нужна помощь',
      'no_checkin' => 'Без check-in',
      'working' => 'Выполняет',
      'on_focus' => 'В фокусе',
      _ => 'Цель взята',
    };

    return DStatusChip(m.publicStatusLabel ?? fallback, tone: tone);
  }
}

// ---- Блок 4 раздела 16. Повестка встречи ---------------------------------

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.session, required this.group});

  final MastermindSession session;
  final MastermindGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MastermindController>();

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: DSectionLabel('Повестка встречи'),
          ),
          const SizedBox(height: DSpace.sm),
          if (session.isCurator)
            ..._curatorView(context, c)
          else
            ..._memberView(context),
        ],
      ),
    );
  }

  // Куратор: полный список с talking points и пересборка (busy-состояние)
  List<Widget> _curatorView(BuildContext context, MastermindController c) {
    if (session.agenda.isEmpty) {
      return [
        Text(
          'Повестка ещё не собрана. Соберите её перед встречей — '
          'она покажет, кого разбирать первым.',
          style: DText.of(context).bodyMuted,
        ),
        const SizedBox(height: DSpace.lg),
        DPrimaryButton(
          label: 'Собрать повестку',
          loading: c.busy,
          onPressed: () => _rebuild(context, c),
        ),
      ];
    }

    return [
      if (session.needAttention > 0) ...[
        Text(
          'Требуют разбора: ${session.needAttention} из ${session.agenda.length}',
          style: DText.of(
            context,
          ).caption.copyWith(color: DColors.of(context).warning),
        ),
        const SizedBox(height: DSpace.sm),
      ],
      for (final (i, item) in session.agenda.indexed) ...[
        if (i > 0)
          Divider(color: DColors.of(context).divider, height: DSpace.lg),
        _AgendaRow(item: item),
      ],
      const SizedBox(height: DSpace.lg),
      DPrimaryButton(
        label: 'Пересобрать повестку',
        loading: c.busy,
        onPressed: () => _rebuild(context, c),
      ),
    ];
  }

  // Участник: своя строка плюс обезличенная сводка. Чужие строки не
  // показываем никогда — фильтруем даже то, что пришло с сервера.
  List<Widget> _memberView(BuildContext context) {
    int? myId;
    for (final m in group.members) {
      if (m.isMe) {
        myId = m.id;
        break;
      }
    }

    final mine = session.agenda.where((i) => i.userId == myId).toList();
    final counts = _summaryRows();

    if (mine.isEmpty && counts.isEmpty) {
      return [
        Text(
          'Повестку соберёт куратор перед встречей.',
          style: DText.of(context).bodyMuted,
        ),
      ];
    }

    return [
      if (mine.isNotEmpty) ...[
        for (final item in mine) _AgendaRow(item: item),
        if (counts.isNotEmpty)
          Divider(color: DColors.of(context).divider, height: DSpace.lg * 1.5),
      ],
      if (counts.isNotEmpty) ...[
        Text('По группе', style: DText.of(context).caption),
        const SizedBox(height: DSpace.xs),
        for (final (label, n) in counts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: DText.of(context).bodyMuted),
                ),
                Text('$n', style: DText.of(context).kpi),
              ],
            ),
          ),
      ],
    ];
  }

  /// Сводка без имён: сколько кого в группе. Нули пропускаем —
  /// пустые категории только удлиняют карточку.
  List<(String, int)> _summaryRows() {
    const labels = [
      ('stuck', 'Просят помощи'),
      ('silent', 'Без check-in'),
      ('behind', 'Отстают'),
      ('no_goal', 'Без цели'),
      ('on_track', 'В графике'),
      ('achieved', 'Цель взята'),
    ];

    return [
      for (final (key, label) in labels)
        if ((session.summary[key] ?? 0) > 0) (label, session.summary[key]!),
    ];
  }

  Future<void> _rebuild(BuildContext context, MastermindController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await c.buildAgenda();

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: DText.of(
                  context,
                ).body.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: DSpace.sm),
            DStatusChip(item.status.label, tone: _tone(item.status)),
          ],
        ),
        if (item.goalTitle != null) ...[
          const SizedBox(height: 2),
          Text(item.goalTitle!, style: DText.of(context).caption),
        ],
        if (item.progressPercent != null) ...[
          const SizedBox(height: 2),
          Text(
            'Прогресс ${item.progressPercent}%'
            '${item.expectedPercent != null ? ' · план ${item.expectedPercent}%' : ''}',
            style: DText.of(context).caption,
          ),
        ],
        if (item.talkingPoint != null) ...[
          const SizedBox(height: DSpace.xs),
          Text(item.talkingPoint!, style: DText.of(context).bodyMuted),
        ],
      ],
    );
  }

  /// Жёлтый — только «требует внимания» (раздел 4); красного у чипов нет.
  static DChipTone _tone(AgendaStatus status) => switch (status) {
    AgendaStatus.stuck ||
    AgendaStatus.silent ||
    AgendaStatus.behind => DChipTone.yellow,
    AgendaStatus.noGoal => DChipTone.muted,
    AgendaStatus.onTrack => DChipTone.greenOutline,
    AgendaStatus.achieved => DChipTone.green,
  };
}

// ---- Блок 5 раздела 16. Мои обязательства --------------------------------

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({required this.items});

  final List<Commitment> items;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MastermindController>();

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Мои обязательства'),
          const SizedBox(height: DSpace.xs),
          for (final (i, item) in items.indexed) ...[
            if (i > 0) Divider(color: DColors.of(context).divider, height: 1),
            _CommitmentRow(
              item: item,
              // busy запрещает повторный tap, пока запрос не завершился
              onToggle: c.busy ? null : () => _toggle(context, c, item.id),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    MastermindController c,
    int id,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await c.toggleCommitment(id);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _CommitmentRow extends StatelessWidget {
  const _CommitmentRow({required this.item, this.onToggle});

  final Commitment item;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    // Просрочка — предупреждение, а не ошибка: warning, не danger
    final overdue = item.isOverdue && !item.isDone;

    return Semantics(
      checked: item.isDone,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          // Цель нажатия не меньше 44 логических пикселей
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: item.isDone
                      ? DColors.of(context).accent
                      : DColors.of(context).textTertiary,
                ),
                const SizedBox(width: DSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.text,
                        style: item.isDone
                            ? DText.of(context).bodyMuted.copyWith(
                                decoration: TextDecoration.lineThrough,
                                decorationColor: DColors.of(
                                  context,
                                ).textTertiary,
                              )
                            : DText.of(context).body,
                      ),
                      if (item.dueOn != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          overdue
                              ? 'до ${Fmt.date(item.dueOn!)} · просрочено'
                              : 'до ${Fmt.date(item.dueOn!)}',
                          style: overdue
                              ? DText.of(context).caption.copyWith(
                                  color: DColors.of(context).warning,
                                )
                              : DText.of(context).caption,
                        ),
                      ],
                    ],
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

// ---- Блок 6 раздела 16. Прошлый протокол ---------------------------------

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.session});

  final SessionBrief session;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Прошлый протокол'),
          DListRow(
            title: 'Протокол встречи',
            subtitle: Fmt.date(session.scheduledAt),
            chevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MastermindProtocolScreen(sessionId: session.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
