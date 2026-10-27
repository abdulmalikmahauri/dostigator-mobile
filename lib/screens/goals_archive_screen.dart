import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/goal.dart';
import '../state/goals_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'goals_screen.dart' show GoalMetricSummary, GoalStepsList;

/// Архив целей: итоги завершённых целей и история check-in.
/// Всё только для чтения — закрытая цель не редактируется,
/// приватность абсолютных значений сохраняется и здесь.
class GoalsArchiveScreen extends StatelessWidget {
  const GoalsArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final archive = goals.archive;

    return DSubScaffold(
      title: 'Архив целей',
      onRefresh: () => goals.load(silent: true),
      children: [
        if (goals.loading && goals.goals.isEmpty) ...[
          const DSkeletonCard(lines: 2),
          const SizedBox(height: DSpace.row),
          const DSkeletonCard(lines: 2),
        ] else if (goals.error != null && goals.goals.isEmpty)
          DErrorState(message: goals.error!, onRetry: goals.load)
        else if (archive.isEmpty)
          const DEmptyState(
            title: 'История появится, когда вы завершите первую цель',
          )
        else
          for (final goal in archive) ...[
            _QuarterCard(goal: goal),
            const SizedBox(height: DSpace.row),
          ],
      ],
    );
  }
}

/// Подпись цели в архиве — её срок. Цель ставится на любой период,
/// поэтому «кварталом» её больше не назвать.
String _periodLabel(Goal goal) => 'Срок до ${Fmt.date(goal.deadline)}';

/// Статус из API, а если сервер его не прислал — честный запасной текст.
String _statusLabel(Goal goal) {
  if (goal.statusLabel.isNotEmpty) return goal.statusLabel;
  return goal.isReached ? 'Цель достигнута' : 'Завершена';
}

/// Карточка завершённой цели в списке: срок, название, итоговый % и статус.
class _QuarterCard extends StatelessWidget {
  const _QuarterCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ArchivedGoalDetailScreen(goal: goal),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSectionLabel(_periodLabel(goal)),
                const SizedBox(height: DSpace.xs),
                Text(goal.title, style: DText.of(context).cardTitle),
                const SizedBox(height: DSpace.sm),
                DStatusChip(
                  _statusLabel(goal),
                  tone: goal.isReached ? DChipTone.green : DChipTone.muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: DSpace.md),
          Text(
            '${goal.progressPercent}%',
            style: DText.of(context).kpi.copyWith(
              fontSize: 22,
              // Зелёная цифра — только у достигнутой цели
              color: goal.isReached
                  ? DColors.of(context).accent
                  : DColors.of(context).textSecondary,
            ),
          ),
          const SizedBox(width: DSpace.xs),
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

/// Read-only деталь архивной цели: итог, метрика (с privacy),
/// шаги и история check-in.
class _ArchivedGoalDetailScreen extends StatelessWidget {
  const _ArchivedGoalDetailScreen({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return DSubScaffold(
      title: 'Завершённая цель',
      children: [
        DBrandCard(
          radius: DRadius.cardLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: DSectionLabel(_periodLabel(goal))),
                  DStatusChip(
                    _statusLabel(goal),
                    tone: goal.isReached ? DChipTone.green : DChipTone.muted,
                  ),
                ],
              ),
              const SizedBox(height: DSpace.md),
              Text(goal.title, style: DText.of(context).h2),
              if (goal.why != null && goal.why!.isNotEmpty) ...[
                const SizedBox(height: DSpace.xs),
                Text(goal.why!, style: DText.of(context).bodyMuted),
              ],
              const SizedBox(height: DSpace.lg),
              // Итог — крупной цифрой: второе большое кольцо
              // в приложении не нужно (раздел 10.6)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${goal.progressPercent}%',
                    style: DText.of(context).ringValue.copyWith(
                      fontSize: 34,
                      color: goal.isReached
                          ? DColors.of(context).accent
                          : DColors.of(context).textPrimary,
                    ),
                  ),
                  const SizedBox(width: DSpace.sm),
                  Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'итоговый прогресс',
                      style: DText.of(context).caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DSpace.lg),
              if (goal.metricName.isNotEmpty) ...[
                Text(goal.metricName, style: DText.of(context).caption),
                const SizedBox(height: DSpace.sm),
              ],
              GoalMetricSummary(goal: goal, currentLabel: 'итог'),
              const SizedBox(height: DSpace.md),
              Text(
                'Срок: до ${Fmt.date(goal.deadline)}',
                style: DText.of(context).caption,
              ),
              if (goal.outcomeNote != null && goal.outcomeNote!.isNotEmpty) ...[
                const SizedBox(height: DSpace.md),
                const Divider(),
                const SizedBox(height: DSpace.md),
                Text(goal.outcomeNote!, style: DText.of(context).bodyMuted),
              ],
            ],
          ),
        ),
        if (goal.steps.isNotEmpty) ...[
          const SizedBox(height: DSpace.section),
          DBrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DSectionLabel('Шаги к цели'),
                const SizedBox(height: DSpace.md),
                // Без onToggleStep: архивная цель read-only (раздел 13)
                GoalStepsList(goal: goal, archived: true),
              ],
            ),
          ),
        ],
        const SizedBox(height: DSpace.section),
        _CheckinHistoryCard(goal: goal),
      ],
    );
  }
}

/// История check-in (раздел 26): «дата — % — комментарий».
/// Отдельный route не создаём — история живёт внутри архива.
class _CheckinHistoryCard extends StatelessWidget {
  const _CheckinHistoryCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    // Копия с сортировкой: порядок из API не гарантирован,
    // а список читается сверху вниз по ходу работы над целью
    final checkins = [...goal.checkins]
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('История check-in'),
          const SizedBox(height: DSpace.md),
          if (checkins.isEmpty)
            Text('Отчётов по этой цели нет', style: DText.of(context).bodyMuted)
          else
            for (var i = 0; i < checkins.length; i++) ...[
              if (i > 0) const Divider(),
              _CheckinRow(goal: goal, checkin: checkins[i]),
            ],
        ],
      ),
    );
  }
}

/// Строка отчёта. Показываем процент, а не абсолютное значение:
/// так требует раздел 26, и так приватность скрытых сумм
/// сохраняется без отдельной ветки.
// TODO(api): деталь конкретного weekly-отчёта (раздел 26, «tap → detail»)
// не открывается — сервер не отдаёт отдельный endpoint отчёта,
// строки оставлены read-only.
class _CheckinRow extends StatelessWidget {
  const _CheckinRow({required this.goal, required this.checkin});

  final Goal goal;
  final GoalCheckin checkin;

  @override
  Widget build(BuildContext context) {
    final comment = checkin.comment;
    final hasComment = comment != null && comment.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              Fmt.shortDate(checkin.weekStart),
              style: DText.of(context).caption,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${_percentOf(goal, checkin.metricValue)}%',
              style: DText.of(context).body.copyWith(
                fontWeight: FontWeight.w500,
                color: DColors.of(context).accent,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasComment ? comment : 'Без комментария',
                  style: hasComment
                      ? DText.of(context).bodyMuted
                      : DText.of(context).caption.copyWith(
                          color: DColors.of(context).textTertiary,
                        ),
                ),
                if (checkin.needsHelp) ...[
                  const SizedBox(height: DSpace.xs),
                  const DStatusChip('Нужна помощь', tone: DChipTone.yellow),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Процент по значению чек-ина. Сервер присылает только абсолютное
/// значение метрики, поэтому процент считаем от «было → цель» —
/// формула работает и для целей на снижение (знаменатель отрицательный).
int _percentOf(Goal goal, double value) {
  final span = goal.metricTarget - goal.metricFrom;
  if (span == 0) return goal.progressPercent;

  return (((value - goal.metricFrom) / span) * 100).round().clamp(0, 100);
}
