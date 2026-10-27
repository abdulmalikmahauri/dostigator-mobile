import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/knowledge.dart';
import '../state/knowledge_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_filter_chip.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';

/// База знаний: курсы, лекции и мастер-классы клуба.
class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  late final _search = TextEditingController(
    text: context.read<KnowledgeController>().query,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<KnowledgeController>();
      if (mounted && !c.loaded && !c.loading) c.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<KnowledgeController>();

    return DSubScaffold(
      title: 'База знаний',
      subtitle: 'Курсы, лекции и мастер-классы клуба.',
      onRefresh: () => c.load(silent: true),
      children: [
        TextField(
          controller: _search,
          onChanged: c.search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск по названию и описанию',
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: DColors.of(context).textSecondary,
            ),
          ),
        ),
        const SizedBox(height: DSpace.sm),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final kind in CourseKindFilter.values.skip(1))
                DFilterChip(
                  label: kind.label,
                  selected: c.kind == kind,
                  // Повторное нажатие снимает фильтр
                  onTap: () =>
                      c.setKind(c.kind == kind ? CourseKindFilter.all : kind),
                ),
            ],
          ),
        ),
        const SizedBox(height: DSpace.section),
        ..._list(context, c),
      ],
    );
  }

  List<Widget> _list(BuildContext context, KnowledgeController c) {
    if (c.loading && !c.loaded) {
      return const [
        DSkeletonCard(lines: 3),
        SizedBox(height: DSpace.md),
        DSkeletonCard(lines: 3),
      ];
    }

    if (c.error != null && !c.loaded) {
      return [DErrorState(message: c.error!, onRetry: c.load)];
    }

    final staleError = c.error != null
        ? [
            DErrorState(message: 'Не удалось обновить список', onRetry: c.load),
            const SizedBox(height: DSpace.md),
          ]
        : const <Widget>[];

    if (c.courses.isEmpty) {
      final filtered =
          c.query.trim().isNotEmpty || c.kind != CourseKindFilter.all;

      return [
        ...staleError,
        DEmptyState(
          title: filtered ? 'Ничего не нашлось' : 'Материалов пока нет',
          message: filtered
              ? 'Попробуйте другое слово или снимите фильтр.'
              : 'Скоро здесь появятся курсы и записи лекций клуба.',
        ),
      ];
    }

    return [
      ...staleError,
      for (final course in c.courses) ...[
        _CourseCard(course: course),
        const SizedBox(height: DSpace.md),
      ],
    ];
  }
}

void openCourse(BuildContext context, Course course) {
  final lessonId = course.firstLessonId;

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      // Лекция из одного урока открывается сразу уроком
      builder: (_) => lessonId != null
          ? LessonScreen(lessonId: lessonId)
          : CourseScreen(courseId: course.id),
    ),
  );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final cover = course.coverUrl;
    final progress = course.progressLabel;

    return DBrandCard(
      onTap: () => openCourse(context, course),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cover != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  semanticLabel: course.title,
                  errorBuilder: (_, _, _) => ColoredBox(color: c.surface3),
                ),
              ),
            ),
            const SizedBox(height: DSpace.md),
          ],
          Text(course.kindLabel, style: t.caption),
          const SizedBox(height: 2),
          Text(course.title, style: t.cardTitle),
          if (course.description != null &&
              course.description!.trim().isNotEmpty) ...[
            const SizedBox(height: DSpace.xs),
            Text(
              course.description!,
              style: t.bodyMuted,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: DSpace.md),
          Row(
            children: [
              Expanded(child: Text(course.metaLabel, style: t.caption)),
              if (!course.isAvailable)
                const DStatusChip(
                  'Только для бизнес-клуба',
                  tone: DChipTone.outline,
                )
              else if (progress != null)
                DStatusChip(
                  progress,
                  tone: course.completedCount >= course.lessonsCount
                      ? DChipTone.green
                      : DChipTone.greenOutline,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
