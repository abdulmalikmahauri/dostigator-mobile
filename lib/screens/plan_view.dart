import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/club_time.dart';
import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/plan.dart';
import '../state/plan_controller.dart';
import '../state/tasks_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import 'habits_view.dart';
import 'tasks_view.dart';

/// Раздел «План»: сверху — как идут дела за две недели, ниже — всё
/// запланированное по дням: задачи, привычки, шаги целей, мероприятия,
/// заседания, встречи группы и обещания группе.
class PlanView extends StatelessWidget {
  const PlanView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlanController>();

    if (c.loading && !c.loaded) {
      return const Column(
        children: [
          DSkeletonCard(lines: 3),
          SizedBox(height: DSpace.md),
          DSkeletonCard(lines: 4),
        ],
      );
    }

    if (c.error != null && !c.loaded) {
      return DErrorState(message: c.error!, onRetry: c.load);
    }

    final stats = c.stats;
    void reload() => c.load(silent: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats != null) ...[
          _StatsCard(stats: stats),
          const SizedBox(height: DSpace.section),
        ],
        if (c.overdue.isNotEmpty) ...[
          const DSectionLabel('Просрочено'),
          const SizedBox(height: DSpace.sm),
          DRowsCard(
            children: [
              for (final t in c.overdue) TaskRow(task: t, onToggled: reload),
            ],
          ),
          const SizedBox(height: DSpace.section),
        ],
        for (final day in c.days) ...[
          DSectionLabel(_dayTitle(day.date)),
          const SizedBox(height: DSpace.sm),
          if (day.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: DSpace.xs),
              child: Text(
                'Ничего не запланировано',
                style: DText.of(context).caption,
              ),
            )
          else
            DRowsCard(
              children: [
                for (final item in day.items)
                  _PlanRow(item: item, onChanged: reload),
              ],
            ),
          const SizedBox(height: DSpace.section),
        ],
        if (c.canShowMore)
          OutlinedButton(
            onPressed: c.loadingMore ? null : c.showMore,
            child: Text(c.loadingMore ? 'Загружаем…' : 'Показать ещё неделю'),
          ),
      ],
    );
  }

  static final _date = DateFormat('d MMMM', 'ru_RU');
  static final _weekday = DateFormat('EEEE', 'ru_RU');

  String _dayTitle(DateTime date) {
    final today = ClubTime.today();
    final diff = date.difference(today).inDays;
    final dayMonth = _date.format(date);

    return switch (diff) {
      0 => 'Сегодня, $dayMonth',
      1 => 'Завтра, $dayMonth',
      _ => '$dayMonth, ${_weekday.format(date)}',
    };
  }
}

/// Две недели одним взглядом: столбики — доля сделанных привычек по дням.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final PlannerStats stats;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final totals = stats.totals;
    final percent = totals.habitsPercent;

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Две недели', style: t.caption),
          const SizedBox(height: DSpace.md),
          SizedBox(height: 64, child: _Bars(days: stats.days)),
          const SizedBox(height: DSpace.lg),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  value: percent == null ? '—' : '$percent%',
                  label: 'привычек сделано',
                ),
              ),
              Expanded(
                child: _Figure(
                  value: '${totals.streak}',
                  label:
                      '${Fmt.word(totals.streak, 'день', 'дня', 'дней')} подряд',
                ),
              ),
              Expanded(
                child: _Figure(
                  value: '${totals.tasksDone}',
                  label: 'задач закрыто',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.kpi.copyWith(fontSize: 20)),
          Text(label, style: t.caption),
        ],
      ),
    );
  }
}

/// Столбики по дням: высота — доля сделанных привычек. День без привычек —
/// пустой, а не нулевой: отдыхать не значит проваливать.
class _Bars extends StatelessWidget {
  const _Bars({required this.days});

  final List<StatsDay> days;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    final planned = days.fold(0, (sum, d) => sum + d.habitsPlanned);
    final done = days.fold(0, (sum, d) => sum + d.habitsDone);

    return Semantics(
      label: 'За две недели сделано $done привычек из $planned запланированных',
      excludeSemantics: true,
      child: CustomPaint(
        painter: _BarsPainter(days: days, bar: c.accent, track: c.surface3),
        size: Size.infinite,
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.days, required this.bar, required this.track});

  final List<StatsDay> days;
  final Color bar;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    const gap = 4.0;
    final width = (size.width - gap * (days.length - 1)) / days.length;
    final trackPaint = Paint()..color = track;
    final barPaint = Paint()..color = bar;
    const radius = Radius.circular(4);

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final left = i * (width + gap);
      final full = Rect.fromLTWH(left, 0, width, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(full, radius), trackPaint);

      if (d.habitsPlanned == 0) continue;

      final share = (d.habitsDone / d.habitsPlanned).clamp(0.0, 1.0);
      if (share == 0) continue;

      final height = size.height * share;
      final rect = Rect.fromLTWH(left, size.height - height, width, height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), barPaint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.days != days || old.bar != bar || old.track != track;
}

/// Строка плана: у привычек и задач — отметка, у встреч — время.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item, required this.onChanged});

  final PlanItem item;
  final VoidCallback onChanged;

  IconData get _icon => switch (item.kind) {
    PlanKind.habit => Icons.repeat,
    PlanKind.task => Icons.check_box_outline_blank,
    PlanKind.step => Icons.flag_outlined,
    PlanKind.event => Icons.event_outlined,
    PlanKind.meeting => Icons.groups_outlined,
    PlanKind.session => Icons.forum_outlined,
    PlanKind.commitment => Icons.handshake_outlined,
    PlanKind.other => Icons.circle_outlined,
  };

  String? get _kindLabel => switch (item.kind) {
    PlanKind.step => 'Шаг цели',
    PlanKind.event => 'Мероприятие',
    PlanKind.meeting => 'Заседание',
    _ => null,
  };

  Future<void> _toggleTask(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<TasksController>().toggle(item.id);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    onChanged();
  }

  Future<void> _mark(BuildContext context) async {
    final changed = await markHabit(
      context,
      id: item.id,
      title: item.title,
      unit: item.unit,
      target: item.target ?? 1,
      value: item.value ?? 0,
      date: item.date,
    );
    if (changed) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final done = item.done ?? false;

    final subtitle = [
      ?_kindLabel,
      if (item.subtitle != null && item.subtitle!.isNotEmpty) item.subtitle!,
      // У простой привычки «сделал / не сделал» счёт «0 из 1» лишний
      if (item.kind == PlanKind.habit &&
          item.target != null &&
          !(item.unit == null && item.target == 1))
        '${item.value ?? 0} из ${item.target}${item.unit == null ? '' : ' ${item.unit}'}',
    ].join(' · ');

    // Привычку отмечают за сегодня и прошедшую неделю — как на сервере
    final today = ClubTime.today();
    final canMark =
        !item.date.isAfter(today) && today.difference(item.date).inDays <= 6;

    final Widget leading;
    if (item.kind == PlanKind.habit && canMark) {
      leading = HabitTodayButton(
        title: item.title,
        value: item.value ?? 0,
        done: done,
        planned: true,
        onTap: () => _mark(context),
      );
    } else if (item.kind == PlanKind.task) {
      leading = Semantics(
        button: true,
        checked: done,
        label: 'Сделано: ${item.title}',
        onTap: () => _toggleTask(context),
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => _toggleTask(context),
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 24,
              color: done ? c.accent : c.textTertiary,
            ),
          ),
        ),
      );
    } else {
      leading = SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          done ? Icons.check_circle : _icon,
          size: 22,
          color: done ? c.accent : c.textSecondary,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.xs),
      child: Row(
        children: [
          leading,
          const SizedBox(width: DSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: t.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: done ? c.textSecondary : null,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.caption),
                ],
              ],
            ),
          ),
          if (item.time != null) ...[
            const SizedBox(width: DSpace.sm),
            Text(
              item.time!,
              style: t.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}
