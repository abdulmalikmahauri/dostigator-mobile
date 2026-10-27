import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/mastermind.dart';
import '../state/mastermind_controller.dart';
import '../widgets/d_avatar.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';

/// Протокол мастермайнда (раздел 17): мета встречи, итоги, свои
/// обязательства со статусами и — только куратору — посещаемость.
///
/// Privacy (раздел 29): обычный участник не получает разбор чужих
/// проблем, поэтому из обязательств показываем только свои, а список
/// участия скрываем даже если сервер его прислал.
class MastermindProtocolScreen extends StatefulWidget {
  const MastermindProtocolScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  State<MastermindProtocolScreen> createState() =>
      _MastermindProtocolScreenState();
}

class _MastermindProtocolScreenState extends State<MastermindProtocolScreen> {
  MastermindSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // При первом вызове из initState _loading уже true — setState не нужен
    if (!_loading) setState(() => _loading = true);

    final session = await context.read<MastermindController>().loadSession(
      widget.sessionId,
    );

    if (!mounted) return;
    setState(() {
      // Неудачный pull-refresh не стирает уже показанный протокол;
      // ошибку показываем только когда показывать больше нечего
      if (session != null) _session = session;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DSubScaffold(
      title: 'Протокол встречи',
      onRefresh: _load,
      children: _children(),
    );
  }

  List<Widget> _children() {
    if (_loading && _session == null) {
      return const [
        DSkeletonCard(lines: 2),
        SizedBox(height: DSpace.section),
        DSkeletonCard(lines: 3),
      ];
    }

    final s = _session;

    // loadSession возвращает null только при ошибке запроса —
    // протокол открывают по id существующей встречи
    if (s == null) {
      return [
        DErrorState(message: 'Не удалось загрузить протокол', onRetry: _load),
      ];
    }

    return [
      _MetaCard(session: s),
      const SizedBox(height: DSpace.section),
      _NotesCard(notes: s.notes),
      const SizedBox(height: DSpace.section),
      _MyCommitmentsCard(items: s.myCommitments),
      // Посещаемость — только куратору (раздел 17, блок 5): обычному
      // участнику чужие детали не показываем, даже если сервер их отдал
      if (s.isCurator && s.attendance.isNotEmpty) ...[
        const SizedBox(height: DSpace.section),
        _AttendanceCard(items: s.attendance),
      ],
    ];
  }
}

// ---- Блок 1 раздела 17. Session meta -------------------------------------

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.session});

  final MastermindSession session;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(session.scheduledAt);

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  session.groupName ?? 'Мастермайнд',
                  style: DText.of(context).cardTitle,
                ),
              ),
              if (session.isHeld) ...[
                const SizedBox(width: DSpace.sm),
                const DStatusChip('Проведена', tone: DChipTone.green),
              ],
            ],
          ),
          const SizedBox(height: DSpace.xs),
          Text(
            '${Fmt.date(session.scheduledAt)} · $time',
            style: DText.of(context).body,
          ),
          if (session.place != null) ...[
            const SizedBox(height: 2),
            Text(session.place!, style: DText.of(context).caption),
          ],
          // TODO(api): номера и темы встречи в API нет — мета без них.
        ],
      ),
    );
  }
}

// ---- Блок 2 раздела 17. Итоги ---------------------------------------------

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String? notes;

  @override
  Widget build(BuildContext context) {
    final hasNotes = notes != null && notes!.trim().isNotEmpty;

    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Итоги'),
          const SizedBox(height: DSpace.sm),
          if (hasNotes)
            Text(notes!, style: DText.of(context).body)
          else
            Text(
              'Итоги встречи не записаны',
              style: DText.of(context).bodyMuted,
            ),
        ],
      ),
    );
  }
}

// ---- Блоки 3–4 раздела 17. Мои обязательства и их статус ------------------

class _MyCommitmentsCard extends StatelessWidget {
  const _MyCommitmentsCard({required this.items});

  final List<Commitment> items;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Мои обязательства'),
          const SizedBox(height: DSpace.sm),
          if (items.isEmpty)
            Text(
              'На этой встрече вы не брали обязательств.',
              style: DText.of(context).bodyMuted,
            )
          else
            for (final (i, item) in items.indexed) ...[
              if (i > 0) Divider(color: DColors.of(context).divider, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.text, style: DText.of(context).body),
                          if (item.dueOn != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'до ${Fmt.date(item.dueOn!)}',
                              style: DText.of(context).caption,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: DSpace.sm),
                    _statusChip(item),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  /// Просрочка — предупреждение (warning), а не ошибка: danger
  /// зарезервирован за сбоями, не за дисциплиной.
  static DStatusChip _statusChip(Commitment item) {
    if (item.isDone) {
      return const DStatusChip('Выполнено', tone: DChipTone.green);
    }
    if (item.isOverdue) {
      return const DStatusChip('Просрочено', tone: DChipTone.yellow);
    }

    return const DStatusChip('В процессе');
  }
}

// ---- Блок 5 раздела 17. Attendance (только куратор) ------------------------

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.items});

  final List<SessionAttendance> items;

  @override
  Widget build(BuildContext context) {
    return DBrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DSectionLabel('Участие'),
          const SizedBox(height: DSpace.xs),
          for (final (i, a) in items.indexed) ...[
            if (i > 0) Divider(color: DColors.of(context).divider, height: 1),
            DListRow(
              leading: DUserAvatar(name: a.name),
              title: a.name,
              // Неявка — рабочий факт протокола, не предупреждение:
              // жёлтый здесь был бы ложной тревогой
              trailing: DStatusChip(
                a.label,
                tone: a.wasPresent ? DChipTone.green : DChipTone.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
