import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/club_time.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/task.dart';
import '../state/tasks_controller.dart';
import '../widgets/d_brand_card.dart';
import '../widgets/d_primary_button.dart';
import '../widgets/d_section_label.dart';
import '../widgets/d_sub_scaffold.dart';

/// Новая задача или правка своей. Кто видит — выбирается явно,
/// по умолчанию — только я.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final Task? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late DateTime? _due = widget.task?.dueOn;
  late TaskVisibility _visibility =
      widget.task?.visibility ?? TaskVisibility.private;

  Map<String, List<String>> _serverErrors = const {};
  bool _saving = false;

  static final _dueLabel = DateFormat('d MMMM y, EEEE', 'ru_RU');

  bool get _editing => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final moscow = ClubTime.today();
    final today = DateTime(moscow.year, moscow.month, moscow.day);
    final current = _due;

    final picked = await showDatePicker(
      context: context,
      initialDate: current == null
          ? today
          : DateTime(current.year, current.month, current.day),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
      locale: const Locale('ru'),
    );

    if (picked != null) {
      setState(
        () => _due = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _serverErrors = const {};
    });

    final tasks = context.read<TasksController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = TaskDraft(
      title: _title.text,
      notes: _notes.text,
      dueOn: _due,
      visibility: _visibility,
    );

    try {
      final task = widget.task;
      if (task == null) {
        await tasks.create(draft);
      } else {
        await tasks.update(task.id, draft);
      }
      if (mounted) await navigator.maybePop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.fieldErrors);
      if (e.fieldErrors.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Task task) async {
    final tasks = context.read<TasksController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('«${task.title}» пропадёт насовсем.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Оставить'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    final error = await tasks.delete(task.id);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final due = _due;
    final task = widget.task;

    return Form(
      key: _formKey,
      child: DSubScaffold(
        title: _editing ? 'Правка задачи' : 'Новая задача',
        children: [
          if (task?.isHidden ?? false) ...[
            Text(
              'Организаторы скрыли эту задачу по жалобе: другие резиденты '
              'её не видят. Для вас она осталась как была.',
              style: t.bodyMuted,
            ),
            const SizedBox(height: DSpace.md),
          ],
          TextFormField(
            controller: _title,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Задача',
              hintText: 'Позвонить поставщику',
              counterText: '',
              errorText: _serverErrors['title']?.first,
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Напишите, что сделать' : null,
          ),
          const SizedBox(height: DSpace.md),
          TextFormField(
            controller: _notes,
            maxLength: 2000,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Подробности',
              hintText: 'Необязательно',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: DSpace.sm),
          DBrandCard(
            onTap: _pickDue,
            padding: const EdgeInsets.symmetric(
              horizontal: DSpace.lg,
              vertical: DSpace.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, color: c.accent, size: 20),
                const SizedBox(width: DSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Срок', style: t.caption),
                      const SizedBox(height: 2),
                      Text(
                        due == null ? 'Без срока' : _dueLabel.format(due),
                        style: due == null
                            ? t.bodyMuted
                            : t.body.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (due != null)
                  IconButton(
                    onPressed: () => setState(() => _due = null),
                    tooltip: 'Убрать срок',
                    icon: Icon(Icons.close, size: 18, color: c.textTertiary),
                  ),
              ],
            ),
          ),

          const SizedBox(height: DSpace.section),
          const DSectionLabel('Кто видит'),
          const SizedBox(height: DSpace.sm),
          for (final v in TaskVisibility.values) ...[
            _VisibilityOption(
              visibility: v,
              selected: _visibility == v,
              onTap: () => setState(() => _visibility = v),
            ),
            const SizedBox(height: DSpace.sm),
          ],

          // Кнопка — последней строкой формы: уезжает вместе с ней
          const SizedBox(height: DSpace.lg),
          DPrimaryButton(
            label: _editing ? 'Сохранить' : 'Сохранить задачу',
            loading: _saving,
            onPressed: _save,
          ),
          if (task != null) ...[
            const SizedBox(height: DSpace.xs),
            TextButton(
              onPressed: _saving ? null : () => _delete(task),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Удалить задачу'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Вариант «кто видит»: выбранный — с зелёной рамкой и галкой.
class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.visibility,
    required this.selected,
    required this.onTap,
  });

  final TaskVisibility visibility;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DBrandCard(
        onTap: onTap,
        borderColor: selected ? c.accentBorder : null,
        background: selected ? c.accentSoft : null,
        padding: const EdgeInsets.symmetric(
          horizontal: DSpace.lg,
          vertical: DSpace.md,
        ),
        child: Row(
          children: [
            Icon(
              switch (visibility) {
                TaskVisibility.public => Icons.public,
                TaskVisibility.internal => Icons.groups_outlined,
                TaskVisibility.private => Icons.lock_outline,
              },
              size: 20,
              color: selected ? c.accent : c.textSecondary,
            ),
            const SizedBox(width: DSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibility.label,
                    style: t.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(visibility.hint, style: t.caption),
                ],
              ),
            ),
            if (selected) Icon(Icons.check, color: c.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
