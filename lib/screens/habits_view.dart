import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/club_time.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/habit.dart';
import '../state/habits_controller.dart';
import '../widgets/d_amount_dialog.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_states.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';
import 'habits_catalog_screen.dart';
import 'habits_rating_screen.dart';

/// Раздел «Привычки»: что веду, отметка за сегодня одним нажатием,
/// неделя точками и стабильность. Ниже — общие привычки клуба и рейтинг.
class HabitsView extends StatelessWidget {
  const HabitsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HabitsController>();
    final colors = DColors.of(context);

    if (c.loading && !c.loaded && c.habits.isEmpty) {
      return const Column(
        children: [
          DSkeletonCard(lines: 2),
          SizedBox(height: DSpace.md),
          DSkeletonCard(lines: 2),
        ],
      );
    }

    if (c.error != null && !c.loaded && c.habits.isEmpty) {
      return DErrorState(message: c.error!, onRetry: c.load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.habits.isEmpty)
          const DEmptyState(
            title: 'Заведите первую привычку',
            message:
                'Отмечайте, что сделали за день, — и увидите, '
                'насколько вы стабильны.',
          )
        else
          for (final h in c.habits) ...[
            _HabitCard(habit: h),
            const SizedBox(height: DSpace.md),
          ],
        const SizedBox(height: DSpace.sm),
        OutlinedButton.icon(
          onPressed: () => _push(context, const HabitFormScreen()),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Новая привычка'),
        ),
        const SizedBox(height: DSpace.section),
        DRowsCard(
          children: [
            DListRow(
              title: 'Общие привычки клуба',
              subtitle: 'Присоединяйтесь со своей нормой',
              leading: Icon(Icons.groups_outlined, color: colors.accent),
              chevron: true,
              onTap: () => _push(context, const HabitsCatalogScreen()),
            ),
            DListRow(
              title: 'Рейтинг стабильности',
              subtitle: 'Кто держит общие привычки лучше всех',
              leading: Icon(
                Icons.leaderboard_outlined,
                color: colors.textSecondary,
              ),
              chevron: true,
              onTap: () => _push(context, const HabitsRatingScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

/// Отметить привычку за день. Простую — одним нажатием, с количеством —
/// через окно с числом. Возвращает true, если отметка ушла.
Future<bool> markHabit(
  BuildContext context, {
  required int id,
  required String title,
  required String? unit,
  required int target,
  required int value,
  required DateTime date,
  bool stale = false,
}) async {
  final habits = context.read<HabitsController>();
  final messenger = ScaffoldMessenger.of(context);
  final int next;

  // Экран открыт со вчера: «сегодня» в данных — уже вчера. Сначала обновляем,
  // иначе отметка ушла бы во вчерашний день
  if (stale) {
    await habits.load(silent: true);
    messenger.showSnackBar(
      const SnackBar(content: Text('Наступил новый день — привычки обновлены')),
    );
    return false;
  }

  if (unit == null && target == 1) {
    next = value > 0 ? 0 : 1;
  } else {
    final choice = await showAmountDialog(
      context,
      title: title,
      message: 'Норма — ${Habit.unitText(target, unit)}',
      initial: value > 0 ? value : target,
      unit: unit,
      confirmLabel: 'Сохранить',
      canClear: value > 0,
    );

    switch (choice) {
      case null:
        return false;
      case AmountCleared():
        next = 0;
      case AmountEntered(:final value):
        next = value;
    }
  }

  final error = await habits.log(id, date, next);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return false;
  }

  return true;
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final h = habit;
    final percent = h.stability.percent;

    return DBrandCard(
      onTap: () => _push(context, HabitDetailScreen(habitId: h.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.title, style: t.cardTitle),
                    const SizedBox(height: 2),
                    Text('${h.norm} · ${h.daysLabel}', style: t.caption),
                  ],
                ),
              ),
              const SizedBox(width: DSpace.md),
              HabitTodayButton(
                title: h.title,
                value: h.today.value,
                done: h.today.done,
                planned: h.today.planned,
                onTap: () => markHabit(
                  context,
                  id: h.id,
                  title: h.title,
                  unit: h.unit,
                  target: h.target,
                  value: h.today.value,
                  date: h.today.date,
                  stale: h.today.date != ClubTime.today(),
                ),
              ),
            ],
          ),
          const SizedBox(height: DSpace.md),
          Row(
            children: [
              HabitWeekDots(week: h.week),
              const Spacer(),
              Text(
                percent == null
                    ? 'Пока без статистики'
                    : 'Стабильность $percent%',
                style: t.caption.copyWith(
                  color: percent == null ? c.textTertiary : c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Кружок отметки за сегодня: пустой, частично (число) или сделано (галка).
class HabitTodayButton extends StatelessWidget {
  const HabitTodayButton({
    super.key,
    required this.title,
    required this.value,
    required this.done,
    required this.planned,
    required this.onTap,
  });

  final String title;
  final int value;
  final bool done;

  /// Сегодня не по плану — отметить можно, но кружок спокойнее.
  final bool planned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final partial = value > 0 && !done;

    final Color border;
    if (done) {
      border = c.accent;
    } else if (partial) {
      border = c.accentBorder;
    } else {
      border = planned ? c.textTertiary : c.divider;
    }

    return Semantics(
      button: true,
      checked: done,
      label: 'Отметить: $title',
      value: done ? 'сделано' : (partial ? 'отмечено $value' : 'не отмечено'),
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? c.accent : Colors.transparent,
            border: Border.all(color: border, width: 1.6),
          ),
          child: done
              ? Icon(Icons.check, size: 22, color: c.background)
              : partial
              ? Text(
                  '$value',
                  style: DText.of(context).caption.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Неделя точками: сделано — зелёная, было в плане и не сделано — контур,
/// не по плану — едва заметная.
class HabitWeekDots extends StatelessWidget {
  const HabitWeekDots({super.key, required this.week});

  final List<HabitDay> week;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in week) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: d.done
                    ? c.accent
                    : (d.planned ? Colors.transparent : c.surface3),
                border: d.planned && !d.done
                    ? Border.all(color: c.textTertiary)
                    : null,
              ),
            ),
            const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}
