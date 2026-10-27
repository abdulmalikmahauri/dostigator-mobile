import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/habit.dart';
import '../state/habits_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';

/// Общий рейтинг стабильности по общим привычкам клуба. Без значков
/// и наград — только кто как держит то, что сам себе пообещал.
class HabitsRatingScreen extends StatefulWidget {
  const HabitsRatingScreen({super.key});

  @override
  State<HabitsRatingScreen> createState() => _HabitsRatingScreenState();
}

class _HabitsRatingScreenState extends State<HabitsRatingScreen> {
  List<HabitRatingRow>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await context.read<HabitsController>().rating();
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return DSubScaffold(
      title: 'Рейтинг стабильности',
      subtitle:
          'Сколько из запланированного сделано за 30 дней — в среднем '
          'по общим привычкам. В рейтинг попадают через неделю после начала.',
      onRefresh: _load,
      children: [
        if (rows == null && _error == null)
          const DSkeletonCard(lines: 4)
        else if (rows == null)
          DErrorState(message: _error!, onRetry: _load)
        else if (rows.isEmpty)
          const DEmptyState(
            title: 'Рейтинг пока пуст',
            message: 'Он появится, когда кто-то неделю поведёт общую привычку.',
          )
        else
          DRowsCard(
            children: [
              for (final (i, r) in rows.indexed)
                RatingRowTile(rank: i + 1, row: r),
            ],
          ),
      ],
    );
  }
}

/// Строка рейтинга: место, человек, процент. Свою строку видно сразу.
class RatingRowTile extends StatelessWidget {
  const RatingRowTile({super.key, required this.rank, required this.row});

  final int rank;
  final HabitRatingRow row;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final habits = row.habits;
    final target = row.target;

    final String? detail;
    if (habits != null) {
      detail = Fmt.plural(habits, 'привычка', 'привычки', 'привычек');
    } else if (!row.inRating) {
      detail = 'набирает неделю';
    } else {
      detail = target == null ? null : 'норма $target';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSpace.sm),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(row.inRating ? '$rank' : '—', style: t.caption),
          ),
          DUserAvatar(name: row.name, photoUrl: row.avatarUrl, size: 36),
          const SizedBox(width: DSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: t.body.copyWith(fontWeight: FontWeight.w500),
                ),
                if (detail != null) Text(detail, style: t.caption),
              ],
            ),
          ),
          if (row.isMe) ...[
            const DStatusChip('Вы', tone: DChipTone.green),
            const SizedBox(width: DSpace.sm),
          ],
          Text(
            row.inRating && row.percent != null ? '${row.percent}%' : '',
            style: t.kpi.copyWith(fontSize: 17),
          ),
        ],
      ),
    );
  }
}
