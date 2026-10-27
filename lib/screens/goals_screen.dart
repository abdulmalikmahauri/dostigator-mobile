import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/goal.dart';
import '../state/goals_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_progress_ring.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import 'checkin_screen.dart';
import 'goal_create_screen.dart';
import 'goal_detail_screen.dart';
import 'goals_archive_screen.dart';

/// Раздел «Цели» в планере: главная цель развёрнута целиком — метрика,
/// шаги, еженедельный check-in; остальные цели в работе идут строками ниже.
/// Целей может быть сколько угодно и на любой срок.
///
/// Порядок блоков — по важности: цель выше check-in, check-in выше
/// всего остального. Крупное кольцо прогресса на экране одно.
class GoalsView extends StatelessWidget {
  const GoalsView({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final main = goals.mainGoal;
    final others = goals.otherGoals;
    // Скелеты только при первой загрузке: при refresh данные уже на экране
    final firstLoading = goals.loading && goals.goals.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (firstLoading) ...[
          const DSkeletonCard(lines: 3),
          const SizedBox(height: DSpace.section),
          const DSkeletonCard(lines: 4),
        ] else if (goals.error != null && goals.goals.isEmpty)
          DErrorState(message: goals.error!, onRetry: goals.load)
        else if (main == null)
          DEmptyState(
            title: 'Поставьте первую цель',
            message:
                'Сформулируйте измеримый результат и шаги, '
                'чтобы начать отслеживать движение.',
            actionLabel: 'Поставить цель',
            onAction: () => _push(context, const GoalCreateScreen()),
          )
        else ...[
          // «Главная» имеет смысл, только когда есть из чего выбирать
          GoalBlocks(
            goal: main,
            label: others.isEmpty ? 'Моя цель' : 'Главная цель',
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: DSpace.section),
            _OtherGoalsCard(goals: others),
          ],
          const SizedBox(height: DSpace.section),
          OutlinedButton.icon(
            onPressed: () => _push(context, const GoalCreateScreen()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Новая цель'),
          ),
        ],
        // Архив показываем всегда: даже без цели в работе у резидента
        // могла остаться история завершённых
        if (!firstLoading) ...[
          const SizedBox(height: DSpace.section),
          DBrandCard(
            padding: const EdgeInsets.symmetric(
              horizontal: DSpace.card,
              vertical: DSpace.xs,
            ),
            onTap: () => _push(context, const GoalsArchiveScreen()),
            child: DListRow(
              title: 'Архив целей',
              subtitle: 'Завершённые цели и их итоги',
              leading: Icon(
                Icons.history,
                size: 22,
                color: DColors.of(context).textSecondary,
              ),
              chevron: true,
            ),
          ),
        ],
      ],
    );
  }
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// Цель целиком: карточка с метрикой, шаги и check-in. Один и тот же набор
/// блоков стоит на вкладке (главная цель) и на экране отдельной цели.
class GoalBlocks extends StatelessWidget {
  const GoalBlocks({super.key, required this.goal, required this.label});

  final Goal goal;

  /// Подпись над названием: «Моя цель», «Главная цель» или просто «Цель».
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActiveGoalCard(goal: goal, label: label),
        const SizedBox(height: DSpace.section),
        if (goal.steps.isNotEmpty) ...[
          _StepsCard(goal: goal),
          const SizedBox(height: DSpace.section),
        ],
        _CheckinCard(goal: goal),
      ],
    );
  }
}

/// Остальные цели в работе: название, срок, процент. Нажатие открывает
/// цель целиком — там же её можно сделать главной.
class _OtherGoalsCard extends StatelessWidget {
  const _OtherGoalsCard({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      padding: const EdgeInsets.fromLTRB(
        DSpace.card,
        DSpace.card,
        DSpace.card,
        DSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Другие цели'),
          const SizedBox(height: DSpace.xs),
          for (final goal in goals)
            DListRow(
              title: goal.title,
              subtitle: goal.checkedInThisWeek
                  ? Fmt.daysLeft(goal.daysLeft)
                  : '${Fmt.daysLeft(goal.daysLeft)} · отчёта за неделю нет',
              trailing: Text(
                '${goal.progressPercent}%',
                style: DText.of(context).kpi.copyWith(fontSize: 17),
              ),
              chevron: true,
              onTap: () => _push(context, GoalDetailScreen(goalId: goal.id)),
            ),
        ],
      ),
    );
  }
}

/// Карточка цели: название, метрика было→сейчас→цель, кольцо прогресса
/// и срок. Единственное крупное кольцо на экране.
class _ActiveGoalCard extends StatelessWidget {
  const _ActiveGoalCard({required this.goal, required this.label});

  final Goal goal;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      radius: DRadius.cardLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: DSectionLabel(label)),
              if (goal.isReached)
                const DStatusChip('Цель достигнута', tone: DChipTone.green),
              // Правка — в той же форме, что и постановка
              IconButton(
                onPressed: () => _push(context, GoalCreateScreen(goal: goal)),
                tooltip: 'Изменить цель',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: DColors.of(context).textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DSpace.xs),
          Text(goal.title, style: DText.of(context).h2),
          if (goal.why != null && goal.why!.isNotEmpty) ...[
            const SizedBox(height: DSpace.xs),
            Text(goal.why!, style: DText.of(context).bodyMuted),
          ],
          const SizedBox(height: DSpace.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (goal.metricName.isNotEmpty) ...[
                      Text(goal.metricName, style: DText.of(context).caption),
                      const SizedBox(height: DSpace.sm),
                    ],
                    GoalMetricSummary(goal: goal),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.md),
              DProgressRing(
                percent: goal.progressPercent,
                size: 104,
                center: Text(
                  '${goal.progressPercent}%',
                  style: DText.of(context).ringValue.copyWith(fontSize: 25),
                ),
              ),
            ],
          ),
          // У достигнутой цели срок больше не подгоняет — его не показываем
          if (!goal.isReached) ...[
            const SizedBox(height: DSpace.lg),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 15,
                  color: goal.isOverdue
                      ? DColors.of(context).warning
                      : DColors.of(context).textSecondary,
                ),
                const SizedBox(width: DSpace.xs),
                Expanded(
                  child: Text(
                    '${Fmt.daysLeft(goal.daysLeft)} · до ${Fmt.date(goal.deadline)}',
                    style: DText.of(context).caption.copyWith(
                      // Жёлтый допустим: вышедший срок — предупреждение
                      color: goal.isOverdue
                          ? DColors.of(context).warning
                          : DColors.of(context).textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Сводка метрики «было → сейчас → цель». Общая для вкладки и архива,
/// чтобы правило приватности жило в одном месте, а не в двух копиях.
class GoalMetricSummary extends StatelessWidget {
  const GoalMetricSummary({
    super.key,
    required this.goal,
    this.currentLabel = 'сейчас',
  });

  final Goal goal;

  /// В архиве «сейчас» превращается в «итог» — значение то же,
  /// но цель уже закрыта.
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    if (goal.hideAbsoluteValues) {
      // Резидент скрыл цифры — наружу выходит только процент
      return Text(
        'Абсолютные значения скрыты — виден только процент',
        style: DText.of(context).caption,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, 'было', goal.metricFrom),
        const SizedBox(height: DSpace.xs),
        _row(context, currentLabel, goal.metricCurrent, accent: true),
        const SizedBox(height: DSpace.xs),
        _row(context, 'цель', goal.metricTarget),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double value, {
    bool accent = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 58,
          child: Text(label, style: DText.of(context).caption),
        ),
        Expanded(
          child: Text(
            Fmt.metric(value, goal.metricUnit),
            style: DText.of(context).kpi.copyWith(
              fontSize: 17,
              // Зелёным — только текущее значение: это ключевая цифра блока
              color: accent
                  ? DColors.of(context).accent
                  : DColors.of(context).textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Блок «ШАГИ К ЦЕЛИ» с отметкой шага по нажатию.
class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Шаги к цели'),
          const SizedBox(height: DSpace.md),
          GoalStepsList(
            goal: goal,
            // Пока идёт запрос — повторные нажатия запрещены (раздел 40)
            onToggleStep: goals.busy ? null : (step) => _toggle(context, step),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, GoalStep step) async {
    final error = await context.read<GoalsController>().toggleStep(
      goal.id,
      step.id,
    );

    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

/// Шаги с вертикальной линией прогресса слева (раздел 13, блок 3).
/// Используется и на вкладке (нажимаемые строки), и в архиве (read-only) —
/// поэтому виджет публичный.
class GoalStepsList extends StatelessWidget {
  const GoalStepsList({
    super.key,
    required this.goal,
    this.onToggleStep,
    this.archived = false,
  });

  final Goal goal;

  /// null — строки read-only: архивная цель или уже идущий запрос.
  final ValueChanged<GoalStep>? onToggleStep;

  /// В архиве нет «текущего» шага: цель закрыта, и невыполненный шаг —
  /// это «не выполнено», а не «в процессе».
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final steps = goal.steps;
    final currentIndex = archived ? -1 : steps.indexWhere((s) => !s.isDone);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            isCurrent: i == currentIndex,
            // Верхний сегмент линии «заливается» выполнением предыдущего шага
            topDone: i > 0 && steps[i - 1].isDone,
            archived: archived,
            onTap: onToggleStep == null ? null : () => onToggleStep!(steps[i]),
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.topDone,
    required this.archived,
    this.onTap,
  });

  final GoalStep step;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final bool topDone;
  final bool archived;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (String label, DChipTone tone) = step.isDone
        ? ('Выполнено', DChipTone.green)
        : isCurrent
        ? ('В процессе', DChipTone.yellow)
        : archived
        ? ('Не выполнено', DChipTone.muted)
        : ('Запланировано', DChipTone.muted);

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                _line(context, visible: !isFirst, done: topDone),
                _marker(context),
                _line(context, visible: !isLast, done: step.isDone),
              ],
            ),
          ),
          const SizedBox(width: DSpace.md),
          Expanded(
            child: Padding(
              // Вертикальный отступ держит высоту строки не ниже 44
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                step.title,
                style: DText.of(context).body.copyWith(
                  color: step.isDone
                      ? DColors.of(context).textSecondary
                      : DColors.of(context).textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: DSpace.sm),
          Center(child: DStatusChip(label, tone: tone)),
        ],
      ),
    );

    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: step.isDone
          ? 'Снять отметку: ${step.title}'
          : 'Отметить выполненным: ${step.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DRadius.input),
        highlightColor: DColors.of(context).accentSoft,
        splashColor: Colors.transparent,
        child: row,
      ),
    );
  }

  /// Сегмент вертикальной линии: зелёный на пройденном участке,
  /// приглушённый — на будущем.
  Widget _line(
    BuildContext context, {
    required bool visible,
    required bool done,
  }) {
    return Expanded(
      child: Center(
        child: SizedBox(
          width: 2,
          height: double.infinity,
          child: ColoredBox(
            color: !visible
                ? Colors.transparent
                : done
                ? DColors.of(context).accent
                : DColors.of(context).divider,
          ),
        ),
      ),
    );
  }

  Widget _marker(BuildContext context) {
    if (step.isDone) {
      return Icon(
        Icons.check_circle,
        size: 20,
        color: DColors.of(context).accent,
      );
    }

    // Текущий шаг — зелёный контур, будущие — приглушённый
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrent
              ? DColors.of(context).accent
              : DColors.of(context).textTertiary,
          width: isCurrent ? 1.8 : 1.2,
        ),
      ),
    );
  }
}

/// Блок «Еженедельный check-in»: CTA на экран отчёта, состояние
/// «выполнено» — как на Пульсе (раздел 12, блок 2).
class _CheckinCard extends StatelessWidget {
  const _CheckinCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      background: DColors.of(context).surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Еженедельный check-in'),
          const SizedBox(height: DSpace.md),
          if (goal.checkedInThisWeek) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Отчёт за эту неделю отправлен',
                    style: DText.of(context).body,
                  ),
                ),
                SizedBox(width: DSpace.sm),
                DStatusChip('Выполнено', tone: DChipTone.green),
              ],
            ),
            const SizedBox(height: DSpace.lg),
            OutlinedButton(
              onPressed: () => _push(context, CheckInScreen(goal: goal)),
              child: const Text('Посмотреть отчёт'),
            ),
          ] else ...[
            Text('Подведите итоги недели', style: DText.of(context).cardTitle),
            const SizedBox(height: DSpace.xs),
            Text(
              'Следующий отчёт — до воскресенья',
              style: DText.of(context).caption,
            ),
            if (goal.missedWeeks > 0) ...[
              const SizedBox(height: DSpace.xs),
              Text(
                // Жёлтое предупреждение без «наказательной» геймификации
                'Без отчёта: ${Fmt.weeks(goal.missedWeeks)}',
                style: DText.of(
                  context,
                ).caption.copyWith(color: DColors.of(context).warning),
              ),
            ],
            const SizedBox(height: DSpace.lg),
            DPrimaryButton(
              label: 'Заполнить',
              trailingArrow: true,
              onPressed: () => _push(context, CheckInScreen(goal: goal)),
            ),
          ],
        ],
      ),
    );
  }
}
