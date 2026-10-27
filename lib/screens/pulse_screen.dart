import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/event.dart';
import '../models/goal.dart';
import '../models/mastermind.dart';
import '../models/resident.dart';
import '../state/auth_controller.dart';
import '../state/events_controller.dart';
import '../state/goals_controller.dart';
import '../state/mastermind_controller.dart';
import '../widgets/d_app_scaffold.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_progress_ring.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import 'card_screen.dart';
import 'checkin_screen.dart';
import 'event_detail_screen.dart';
import 'goal_create_screen.dart';

/// Пульс — первый экран. За несколько секунд отвечает на вопросы:
/// где я относительно цели, нужен ли check-in, когда мастермайнд,
/// что с обязательствами, событиями и доступом в клуб.
///
/// Порядок блоков — по важности: цель > check-in > мастермайнд >
/// обязательства > события > доступ. Единственное исключение —
/// неоплаченный взнос: он встаёт выше всего, потому что внизу экрана
/// о нём никто не узнавал.
class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key, required this.onOpenTab});

  /// Переключение корневой вкладки: 1 — Цели, 2 — Группа, 3 — События.
  /// Пульс не открывает вкладки push-ем, чтобы не плодить дубли в стеке.
  final void Function(int index) onOpenTab;

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  @override
  void initState() {
    super.initState();
    // После первого кадра: load() зовёт notifyListeners, а уведомлять
    // слушателей во время build запрещено фреймворком.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GoalsController>().load();
      context.read<MastermindController>().load();
      context.read<EventsController>().load();
      context.read<AuthController>().refreshResident();
    });
  }

  Future<void> _refresh() {
    return Future.wait([
      context.read<GoalsController>().load(silent: true),
      context.read<MastermindController>().load(silent: true),
      context.read<EventsController>().load(silent: true),
      context.read<AuthController>().refreshResident(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final mastermind = context.watch<MastermindController>();
    final events = context.watch<EventsController>();
    final resident = context.watch<AuthController>().resident;

    final sections = <Widget>[
      ..._feeSection(resident),
      _goalSection(goals),
      ..._checkinSection(goals),
      ..._mastermindSection(mastermind),
      ..._commitmentsSection(mastermind),
      ..._eventSection(events),
      ..._accessSection(resident),
    ];

    return DAppScaffold(
      title: 'Пульс',
      subtitle: 'Фокус. Действие. Результат.',
      wedge: true,
      onRefresh: _refresh,
      children: [
        for (final (i, section) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: DSpace.section),
          section,
        ],
      ],
    );
  }

  // ---- Блок 1. Фокус недели --------------------------------------------

  Widget _goalSection(GoalsController goals) {
    if (goals.loading && goals.goals.isEmpty) {
      return const DSkeletonCard(lines: 3);
    }

    if (goals.error != null && goals.goals.isEmpty) {
      return DErrorState(message: goals.error!, onRetry: () => goals.load());
    }

    final goal = goals.mainGoal;

    if (goal == null) {
      return DEmptyState(
        title: 'Поставьте первую цель',
        message:
            'Сформулируйте измеримый результат и шаги, '
            'чтобы начать отслеживать движение.',
        actionLabel: 'Поставить цель',
        onAction: _openGoalCreate,
      );
    }

    return _GoalFocusCard(
      goal: goal,
      othersCount: goals.otherGoals.length,
      onTap: () => widget.onOpenTab(1),
    );
  }

  void _openGoalCreate() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const GoalCreateScreen()));
  }

  // ---- Блок 2. Check-in недели -----------------------------------------

  List<Widget> _checkinSection(GoalsController goals) {
    final main = goals.mainGoal;

    // Без цели в работе отчитываться не о чем — блок не показываем.
    if (main == null) return const [];

    // Зовём туда, где отчёта ещё нет: главная цель могла быть уже отмечена,
    // а вторая — нет.
    final pending = goals.pendingCheckins;
    final goal = pending.isEmpty ? main : pending.first;

    return [
      _CheckinCard(
        goal: goal,
        // Одной цели подпись не нужна — и так понятно, о чём отчёт
        showGoalTitle: goals.activeGoals.length > 1,
        onFill: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CheckInScreen(goal: goal)),
        ),
      ),
    ];
  }

  // ---- Блок 3. Ближайший мастермайнд -----------------------------------

  List<Widget> _mastermindSection(MastermindController mastermind) {
    if (mastermind.loading && mastermind.group == null) {
      return const [DSkeletonCard(lines: 2)];
    }

    if (mastermind.error != null && mastermind.group == null) {
      return [
        DErrorState(
          message: mastermind.error!,
          onRetry: () => mastermind.load(),
        ),
      ];
    }

    final group = mastermind.group;

    // Группа не назначена — на Пульсе блок скрываем, объяснение
    // резидент увидит на вкладке «Группа».
    if (group == null) return const [];

    return [_MastermindCard(group: group, onTap: () => widget.onOpenTab(2))];
  }

  // ---- Блок 4. Мои обязательства ---------------------------------------

  List<Widget> _commitmentsSection(MastermindController mastermind) {
    final items = mastermind.myCommitments;

    if (items.isEmpty) return const [];

    return [_CommitmentsCard(items: items, onTap: () => widget.onOpenTab(2))];
  }

  // ---- Блок 5. Ближайшее событие ---------------------------------------

  List<Widget> _eventSection(EventsController events) {
    if (events.loading && events.upcoming.isEmpty) {
      return const [DSkeletonCard(lines: 2)];
    }

    if (events.error != null && events.upcoming.isEmpty) {
      return [
        DErrorState(message: events.error!, onRetry: () => events.load()),
      ];
    }

    final future = events.upcoming.where((e) => !e.isPast).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // Пустую афишу на Пульсе не анонсируем: приоритет экрана —
    // цель и check-in, а «событий нет» скажет вкладка «События».
    if (future.isEmpty) return const [];

    final event = future.first;

    return [
      _EventCard(
        event: event,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventDetailScreen(event: event),
          ),
        ),
      ),
    ];
  }

  // ---- Взнос: выше всего, если не оплачен -----------------------------

  List<Widget> _feeSection(Resident? resident) {
    final overdue = resident?.overdueMembership;

    return overdue == null
        ? const []
        : [_MembershipWarningCard(membership: overdue)];
  }

  // ---- Блок 6. Доступ в клуб -------------------------------------------

  List<Widget> _accessSection(Resident? resident) {
    if (resident == null) return const [];

    // При долге карточку доступа не показываем: QR, который не сработает
    // на стойке, хуже честного предупреждения — а оно уже стоит наверху.
    if (resident.overdueMembership != null) return const [];

    return [
      _AccessCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ResidentCardScreen()),
        ),
      ),
    ];
  }
}

/// Часы и минуты. Fmt времени пока не форматирует, а «19:00» из двух
/// полей надёжнее, чем тянуть отдельный DateFormat ради этого.
String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Главная карточка: главная цель, кольцо прогресса и четыре KPI.
class _GoalFocusCard extends StatelessWidget {
  const _GoalFocusCard({
    required this.goal,
    required this.othersCount,
    required this.onTap,
  });

  final Goal goal;

  /// Сколько ещё целей в работе, кроме этой.
  final int othersCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      radius: DRadius.cardLarge,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DSectionLabel('Фокус недели'),
                    const SizedBox(height: DSpace.sm),
                    Text(goal.title, style: DText.of(context).h2),
                    const SizedBox(height: DSpace.xs),
                    Text(
                      othersCount == 0
                          ? 'Цель в работе'
                          : 'Главная цель · ещё $othersCount в работе',
                      style: DText.of(context).caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.md),
              // Единственное крупное кольцо на вьюпорте (раздел 10.6)
              DProgressRing(
                percent: goal.progressPercent,
                size: 108,
                center: Text(
                  '${goal.progressPercent}%',
                  style: DText.of(context).ringValue.copyWith(fontSize: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: DSpace.lg),
          _GoalKpis(goal: goal),
        ],
      ),
    );
  }
}

/// KPI-сетка карточки цели. При включённой приватности абсолютные
/// суммы не показываем вовсе — остаются только процент и срок.
class _GoalKpis extends StatelessWidget {
  const _GoalKpis({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final progress = _Kpi(label: 'Прогресс', value: '${goal.progressPercent}%');
    final daysLeft = _Kpi(
      label: 'Остаётся',
      value: goal.daysLeft >= 0
          ? Fmt.plural(goal.daysLeft, 'день', 'дня', 'дней')
          : 'срок вышел',
    );

    if (goal.hideAbsoluteValues) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: progress),
              Expanded(child: daysLeft),
            ],
          ),
          const SizedBox(height: DSpace.md),
          Text(
            'Абсолютные значения скрыты настройкой приватности',
            style: DText.of(context).caption,
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: 'Результат',
                value: Fmt.metric(goal.metricCurrent, goal.metricUnit),
              ),
            ),
            Expanded(
              child: _Kpi(
                label: 'Цель',
                value: Fmt.metric(goal.metricTarget, goal.metricUnit),
              ),
            ),
          ],
        ),
        const SizedBox(height: DSpace.md),
        Row(
          children: [
            Expanded(child: progress),
            Expanded(child: daysLeft),
          ],
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSectionLabel(label),
        const SizedBox(height: 4),
        Text(value, style: DText.of(context).kpi),
      ],
    );
  }
}

/// Check-in недели: до отправки — призыв и кнопка, после — тихое
/// подтверждение без кнопки (раздел 12, блок 2).
class _CheckinCard extends StatelessWidget {
  const _CheckinCard({
    required this.goal,
    required this.showGoalTitle,
    required this.onFill,
  });

  final Goal goal;

  /// Целей несколько — подписываем, по какой из них этот отчёт.
  final bool showGoalTitle;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final done = goal.checkedInThisWeek;

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DSectionLabel('Check-in недели'),
              const Spacer(),
              if (done)
                const DStatusChip('Выполнено', tone: DChipTone.green)
              else if (goal.missedWeeks > 0)
                // Жёлтый — предупреждение, без «наказательной» геймификации
                DStatusChip(
                  'Пропущено: ${Fmt.weeks(goal.missedWeeks)}',
                  tone: DChipTone.yellow,
                ),
            ],
          ),
          const SizedBox(height: DSpace.sm),
          if (done)
            Text('Отчёт за эту неделю отправлен', style: DText.of(context).body)
          else ...[
            Text('Подведите итоги недели', style: DText.of(context).cardTitle),
            if (showGoalTitle) ...[
              const SizedBox(height: DSpace.xs),
              Text(goal.title, style: DText.of(context).body),
            ],
            const SizedBox(height: DSpace.xs),
            Text(
              'Следующий отчёт: до воскресенья',
              style: DText.of(context).bodyMuted,
            ),
            const SizedBox(height: DSpace.lg),
            DPrimaryButton(
              label: 'Заполнить',
              trailingArrow: true,
              onPressed: onFill,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ближайший мастермайнд: дата и время встречи или честное
/// «пока не назначена». Tap ведёт на вкладку «Группа».
class _MastermindCard extends StatelessWidget {
  const _MastermindCard({required this.group, required this.onTap});

  final MastermindGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = group.nextSession;

    return DBrandCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Ближайший мастермайнд'),
          const SizedBox(height: DSpace.sm),
          if (session == null)
            Text(
              'Ближайшая встреча пока не назначена',
              style: DText.of(context).bodyMuted,
            )
          else
            Row(
              children: [
                const _IconBadge(icon: Icons.groups_outlined),
                const SizedBox(width: DSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TODO(api): темы встречи в API нет — показываем
                      // название группы вместо темы.
                      Text(group.name, style: DText.of(context).cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.date(session.scheduledAt)} · '
                        '${_time(session.scheduledAt)}',
                        style: DText.of(context).caption,
                      ),
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
        ],
      ),
    );
  }
}

/// До трёх ближайших обязательств со статусами. Полный список — на
/// вкладке «Группа», сюда попадает только вершина.
class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({required this.items, required this.onTap});

  final List<Commitment> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Мои обязательства'),
          const SizedBox(height: DSpace.xs),
          for (final c in items.take(3))
            DListRow(
              title: c.text,
              subtitle: c.dueOn == null ? null : 'до ${Fmt.date(c.dueOn!)}',
              trailing: _commitmentChip(c),
            ),
        ],
      ),
    );
  }

  /// Просрочка — жёлтая: это предупреждение, а не приговор (раздел 4).
  DStatusChip _commitmentChip(Commitment c) {
    if (c.isDone) return const DStatusChip('Выполнено', tone: DChipTone.green);
    if (c.isOverdue) {
      return const DStatusChip('Просрочено', tone: DChipTone.yellow);
    }
    return const DStatusChip('Открыто', tone: DChipTone.muted);
  }
}

/// Ближайшее событие клуба одной строкой: название, дата, место.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final ClubEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      Fmt.date(event.startsAt),
      if (event.place != null && event.place!.isNotEmpty) event.place!,
    ].join(' · ');

    return DBrandCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Ближайшее событие'),
          const SizedBox(height: DSpace.xs),
          DListRow(title: event.title, subtitle: details, chevron: true),
        ],
      ),
    );
  }
}

/// Компактная карточка доступа: маленький QR-знак, вся карточка —
/// одна touch-цель, ведёт на карту резидента.
class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      onTap: onTap,
      child: Row(
        children: [
          const _IconBadge(icon: Icons.qr_code_2),
          const SizedBox(width: DSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSectionLabel('Доступ в клуб'),
                SizedBox(height: 4),
                Text('Покажите QR на стойке', style: DText.of(context).body),
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

/// Плашка о задолженности — первым блоком экрана. Оплаты в приложении
/// нет — только направляем к организатору.
class _MembershipWarningCard extends StatelessWidget {
  const _MembershipWarningCard({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      borderColor: DColors.of(context).warning.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: DColors.of(context).warning,
          ),
          const SizedBox(width: DSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Взнос не оплачен', style: DText.of(context).cardTitle),
                const SizedBox(height: DSpace.xs),
                Text(
                  '«${membership.tierLabel}»: доступ в клуб приостановлен. '
                  'По оплате обратитесь к организатору.',
                  style: DText.of(context).bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Квадратная подложка под иконку блока: 44×44 — минимальная touch-цель,
/// даже когда иконка декоративная.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: DColors.of(context).accentSoft,
        borderRadius: BorderRadius.circular(DRadius.input),
      ),
      child: Icon(icon, size: 24, color: DColors.of(context).accent),
    );
  }
}
