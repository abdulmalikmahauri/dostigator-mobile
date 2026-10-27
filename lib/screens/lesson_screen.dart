import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/knowledge.dart';
import '../state/knowledge_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_states.dart';
import '../widgets/d_status_chip.dart';
import '../widgets/d_sub_scaffold.dart';
import '../widgets/video_embed/video_embed.dart';

/// Урок: видео, текст, отметка «изучено» и переход к соседним урокам.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lessonId});

  final int lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Lesson? _lesson;
  String? _error;
  bool _playing = false;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    try {
      final lesson = await context.read<KnowledgeController>().lesson(
        widget.lessonId,
      );
      if (mounted) setState(() => _lesson = lesson);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _mark(bool completed) async {
    if (_marking) return;
    setState(() => _marking = true);

    final knowledge = context.read<KnowledgeController>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final lesson = await knowledge.mark(
        widget.lessonId,
        completed: completed,
      );
      if (mounted) setState(() => _lesson = lesson);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  void _go(int lessonId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LessonScreen(lessonId: lessonId)),
    );
  }

  Future<void> _openOutside(LessonVideo video) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(video.watchUrl);
    var opened = false;

    if (uri != null && VideoHosts.isAllowed(video.watchUrl)) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не получилось открыть видео')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;

    return DSubScaffold(
      title: lesson?.courseTitle ?? 'Урок',
      onRefresh: _load,
      children: [
        if (lesson == null && _error == null)
          const DSkeletonCard(lines: 5)
        else if (lesson == null)
          DErrorState(message: _error!, onRetry: _load)
        else
          ..._blocks(context, lesson),
      ],
    );
  }

  List<Widget> _blocks(BuildContext context, Lesson lesson) {
    final t = DText.of(context);
    final video = lesson.video;
    // Адрес плеера собирает сервер, но встраиваем только VK Видео и Rutube
    final canEmbed = video != null && VideoHosts.isAllowed(video.embedUrl);
    final canOpen = video != null && VideoHosts.isAllowed(video.watchUrl);

    return [
      Text(
        [
          lesson.courseKindLabel,
          if (lesson.total > 1) 'урок ${lesson.number} из ${lesson.total}',
          if (lesson.durationMinutes != null)
            durationLabel(lesson.durationMinutes!),
        ].where((s) => s.isNotEmpty).join(' · '),
        style: t.caption,
      ),
      const SizedBox(height: DSpace.xs),
      Text(lesson.title, style: t.h1),
      const SizedBox(height: DSpace.lg),

      if (!lesson.isAvailable)
        const DEmptyState(
          title: 'Урок открыт для резидентов бизнес-клуба',
          message:
              'Перейти в бизнес-клуб можно через организатора — '
              'и вся база знаний станет доступна.',
        )
      else ...[
        if (canEmbed) ...[
          if (_playing)
            VideoEmbed(url: video.embedUrl, title: lesson.title)
          else
            _VideoPoster(
              providerLabel: video.providerLabel,
              onPlay: () => setState(() => _playing = true),
            ),
        ],
        if (canOpen) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openOutside(video),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Открыть в ${video.providerLabel}'),
            ),
          ),
          const SizedBox(height: DSpace.sm),
        ],
        for (final p in lesson.paragraphs) ...[
          SelectableText(p, style: t.body.copyWith(height: 1.6)),
          const SizedBox(height: DSpace.md),
        ],
        const SizedBox(height: DSpace.md),
        if (lesson.isCompleted)
          Row(
            children: [
              const DStatusChip('Изучено', tone: DChipTone.green),
              const SizedBox(width: DSpace.sm),
              TextButton(
                onPressed: _marking ? null : () => _mark(false),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Снять отметку'),
              ),
            ],
          )
        else
          DPrimaryButton(
            label: 'Отметить как изученное',
            loading: _marking,
            onPressed: () => _mark(true),
          ),
      ],

      if (lesson.prevId != null || lesson.nextId != null) ...[
        const SizedBox(height: DSpace.section),
        Row(
          children: [
            if (lesson.prevId != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _go(lesson.prevId!),
                  child: const Text('Предыдущий урок'),
                ),
              ),
            if (lesson.prevId != null && lesson.nextId != null)
              const SizedBox(width: DSpace.sm),
            if (lesson.nextId != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _go(lesson.nextId!),
                  child: const Text('Следующий урок'),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}

/// Заставка вместо плеера: видео грузится, только когда его попросили —
/// так урок открывается быстро и не тратит мобильный интернет.
class _VideoPoster extends StatelessWidget {
  const _VideoPoster({required this.providerLabel, required this.onPlay});

  final String providerLabel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final c = DColors.of(context);
    final t = DText.of(context);

    return Semantics(
      button: true,
      label: 'Смотреть видео, $providerLabel',
      onTap: onPlay,
      excludeSemantics: true,
      child: DBrandCard(
        onTap: onPlay,
        background: c.surface2,
        padding: EdgeInsets.zero,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent,
                ),
                child: Icon(Icons.play_arrow, size: 36, color: c.background),
              ),
              const SizedBox(height: DSpace.md),
              Text(
                'Смотреть видео',
                style: t.body.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(providerLabel, style: t.caption),
            ],
          ),
        ),
      ),
    );
  }
}
