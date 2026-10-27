import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/knowledge.dart';
import '../state/knowledge_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_list_row.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'lesson_screen.dart';

/// Курс: о чём он, сколько пройдено и уроки по порядку.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.courseId});

  final int courseId;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  CourseDetail? _detail;
  String? _error;
  late final KnowledgeController _knowledge;
  late int _version;

  @override
  void initState() {
    super.initState();
    _knowledge = context.read<KnowledgeController>();
    _version = _knowledge.progressVersion;
    _knowledge.addListener(_onKnowledgeChanged);
    _load();
  }

  @override
  void dispose() {
    _knowledge.removeListener(_onKnowledgeChanged);
    super.dispose();
  }

  /// Отметили урок — здесь или в соседнем, открытом кнопкой «Следующий урок».
  void _onKnowledgeChanged() {
    if (_knowledge.progressVersion == _version) return;
    _version = _knowledge.progressVersion;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    try {
      final detail = await context.read<KnowledgeController>().course(
        widget.courseId,
      );
      if (mounted) setState(() => _detail = detail);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Галочки обновятся сами: курс слушает отметки «изучено».
  void _open(LessonSummary lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonScreen(lessonId: lesson.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return DSubScaffold(
      title: detail?.course.kindLabel ?? 'Материал',
      onRefresh: _load,
      children: [
        if (detail == null && _error == null)
          const DSkeletonCard(lines: 4)
        else if (detail == null)
          DErrorState(message: _error!, onRetry: _load)
        else
          ..._blocks(context, detail),
      ],
    );
  }

  List<Widget> _blocks(BuildContext context, CourseDetail detail) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final course = detail.course;
    final progress = course.progressLabel;

    return [
      DBrandCard(
        background: c.surface2,
        radius: DRadius.cardLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.kindLabel, style: t.caption),
            const SizedBox(height: DSpace.xs),
            Text(course.title, style: t.h1),
            if (course.description != null &&
                course.description!.trim().isNotEmpty) ...[
              const SizedBox(height: DSpace.md),
              Text(course.description!.trim(), style: t.body),
            ],
            const SizedBox(height: DSpace.md),
            Text(course.metaLabel, style: t.caption),
            if (!course.isAvailable) ...[
              const SizedBox(height: DSpace.md),
              const DStatusChip(
                'Только для бизнес-клуба',
                tone: DChipTone.outline,
              ),
            ] else if (progress != null) ...[
              const SizedBox(height: DSpace.md),
              DStatusChip(progress, tone: DChipTone.green),
            ],
          ],
        ),
      ),
      const SizedBox(height: DSpace.section),
      const DSectionLabel('Уроки'),
      const SizedBox(height: DSpace.sm),
      if (detail.lessons.isEmpty)
        Text('Уроки скоро появятся', style: t.bodyMuted)
      else
        DRowsCard(
          children: [
            for (final (i, lesson) in detail.lessons.indexed)
              DListRow(
                title: lesson.title,
                subtitle: [
                  if (lesson.durationMinutes != null)
                    durationLabel(lesson.durationMinutes!),
                  lesson.hasVideo ? 'видео' : 'текст',
                ].join(' · '),
                leading: _LessonMark(number: i + 1, done: lesson.isCompleted),
                chevron: true,
                onTap: () => _open(lesson),
              ),
          ],
        ),
    ];
  }
}

/// Номер урока или галка, если урок изучен.
class _LessonMark extends StatelessWidget {
  const _LessonMark({required this.number, required this.done});

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);

    return Semantics(
      label: done ? 'Изучено' : 'Урок $number',
      excludeSemantics: true,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? c.accent : Colors.transparent,
          border: done ? null : Border.all(color: c.divider),
        ),
        child: done
            ? Icon(Icons.check, size: 18, color: c.background)
            : Text('$number', style: DText.of(context).caption),
      ),
    );
  }
}
