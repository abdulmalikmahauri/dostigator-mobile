import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/club_time.dart';
import '../core/content_report.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/habit.dart';
import '../state/habits_controller.dart';
import '../widgets/d_amount_dialog.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_sub_scaffold.dart';
import 'habit_form_screen.dart';
import 'habits_rating_screen.dart';
import 'habits_view.dart';

/// Привычка целиком: месяц по дням, стабильность, своя норма
/// и — у общей — кто ещё её ведёт и как держит.
class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  Habit? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Зовётся и после ожиданий — экран к этому времени могли закрыть
    if (!mounted) return;

    try {
      final detail = await context.read<HabitsController>().detail(
        widget.habitId,
      );
      if (mounted) setState(() => _detail = detail);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _changeTarget(Habit h) async {
    final habits = context.read<HabitsController>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showAmountDialog(
      context,
      title: 'Своя норма',
      initial: h.target,
      unit: h.unit,
      confirmLabel: 'Сохранить',
    );
    if (choice is! AmountEntered) return;

    try {
      await habits.update(h.id, {'target': choice.value});
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _leave(Habit h) async {
    final habits = context.read<HabitsController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перестать вести?'),
        content: Text(
          '«${h.title}» пропадёт из ваших привычек. '
          'Вернуться можно в любой момент — начнёте заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Оставить'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Перестать'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    final error = await habits.leave(h.id);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // Отметка с этого экрана сразу меняет привычку в списке — берём свежую
    final listed = context.watch<HabitsController>().habits.where(
      (h) => h.id == widget.habitId,
    );
    final detail = _detail;
    final h = listed.isEmpty ? detail : listed.first;

    return DSubScaffold(
      title: 'Привычка',
      onRefresh: _load,
      children: [
        if (h == null && _error == null)
          const DSkeletonCard(lines: 4)
        else if (h == null)
          DErrorState(message: _error!, onRetry: _load)
        else
          ..._blocks(context, h, detail),
      ],
    );
  }

  List<Widget> _blocks(BuildContext context, Habit h, Habit? detail) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final s = h.stability;
    final soleOwner = h.isOwner && h.participantsCount <= 1;

    return [
      DBrandCard(
        background: c.surface2,
        radius: DRadius.cardLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.title, style: t.h2),
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
                  onTap: () async {
                    final marked = await markHabit(
                      context,
                      id: h.id,
                      title: h.title,
                      unit: h.unit,
                      target: h.target,
                      value: h.today.value,
                      date: h.today.date,
                      stale: h.today.date != ClubTime.today(),
                    );
                    if (marked) await _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: DSpace.lg),
            Text(s.percent == null ? '—' : '${s.percent}%', style: t.kpi),
            Text(
              s.planned == 0
                  ? 'Статистика появится после первого дня'
                  : 'стабильность: сделано ${s.done} из ${s.planned} '
                        'за 30 дней',
              style: t.caption,
            ),
          ],
        ),
      ),

      if (detail != null && detail.calendar.isNotEmpty) ...[
        const SizedBox(height: DSpace.section),
        const DSectionLabel('Последние 30 дней'),
        const SizedBox(height: DSpace.sm),
        DBrandCard(child: HabitMonthGrid(days: detail.calendar)),
      ],

      const SizedBox(height: DSpace.section),
      OutlinedButton(
        onPressed: () => _changeTarget(h),
        child: Text('Своя норма: ${h.norm}'),
      ),
      if (soleOwner) ...[
        const SizedBox(height: DSpace.sm),
        OutlinedButton(
          onPressed: () => Navigator.of(context)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => HabitFormScreen(habit: h),
                ),
              )
              .then((_) => _load()),
          child: const Text('Изменить привычку'),
        ),
      ],

      if (detail != null && detail.rating.isNotEmpty) ...[
        const SizedBox(height: DSpace.section),
        DSectionLabel('Ведут: ${detail.rating.length}'),
        const SizedBox(height: DSpace.sm),
        DRowsCard(
          children: [
            for (final (i, r) in detail.rating.indexed)
              RatingRowTile(rank: i + 1, row: r),
          ],
        ),
      ],

      const SizedBox(height: DSpace.section),
      TextButton(
        onPressed: () => _leave(h),
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        child: const Text('Перестать вести'),
      ),
      if (h.isListed && !h.isOwner)
        TextButton(
          onPressed: () => reportContent(
            context,
            type: ReportedContent.habit,
            id: h.id,
            title: h.title,
          ),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          child: const Text('Пожаловаться на привычку'),
        ),
    ];
  }
}

/// Месяц привычки клеточками по неделям: сделано — зелёная,
/// было в плане и не сделано — контур, не по плану — пусто.
class HabitMonthGrid extends StatelessWidget {
  const HabitMonthGrid({super.key, required this.days});

  final List<HabitDay> days;

  static final _label = DateFormat('d MMMM', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final done = days.where((d) => d.done).length;
    final planned = days.where((d) => d.planned).length;

    return Semantics(
      label: 'За 30 дней сделано $done из $planned запланированных',
      excludeSemantics: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final d in days)
            Tooltip(
              message: _label.format(d.date),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: d.done
                      ? c.accent
                      : (d.planned ? Colors.transparent : c.surface3),
                  border: d.planned && !d.done
                      ? Border.all(color: c.textTertiary)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
