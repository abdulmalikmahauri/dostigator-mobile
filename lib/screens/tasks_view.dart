import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/task.dart';
import '../state/tasks_controller.dart';
import '../widgets/d_filter_chip.dart';
import '../widgets/d_rows_card.dart';
import '../widgets/d_states.dart';
import 'task_form_screen.dart';

/// Раздел «Задачи»: в работе и сделанные. Отметка — одним нажатием.
class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TasksController>();
    final list = _showDone ? c.done : c.open;

    if (c.loading && !c.loaded && c.open.isEmpty) {
      return const Column(
        children: [
          DSkeletonCard(lines: 3),
          SizedBox(height: DSpace.md),
          DSkeletonCard(lines: 2),
        ],
      );
    }

    if (c.error != null && !c.loaded && c.open.isEmpty) {
      return DErrorState(message: c.error!, onRetry: c.load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              DFilterChip(
                label: 'В работе',
                selected: !_showDone,
                onTap: () => setState(() => _showDone = false),
              ),
              DFilterChip(
                label: 'Сделанные',
                selected: _showDone,
                onTap: () => setState(() => _showDone = true),
              ),
            ],
          ),
        ),
        const SizedBox(height: DSpace.md),
        if (list.isEmpty)
          DEmptyState(
            title: _showDone ? 'Сделанных задач пока нет' : 'Задач пока нет',
            message: _showDone
                ? null
                : 'Запишите, что нужно сделать, — со сроком или без.',
          )
        else
          DRowsCard(children: [for (final t in list) TaskRow(task: t)]),
        const SizedBox(height: DSpace.section),
        OutlinedButton.icon(
          onPressed: () => openTaskForm(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Новая задача'),
        ),
      ],
    );
  }
}

void openTaskForm(BuildContext context, {Task? task}) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => TaskFormScreen(task: task)));
}

final _due = DateFormat('d MMMM', 'ru_RU');

/// Строка задачи: кружок «сделано», название, срок и кто видит.
class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.task, this.onToggled});

  final Task task;

  /// Что сделать после отметки — например, перечитать план.
  final VoidCallback? onToggled;

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<TasksController>().toggle(task.id);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    onToggled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = DText.of(context);
    final c = DColors.of(context);
    final due = task.dueOn;

    final details = [
      if (due != null)
        task.isOverdue ? 'просрочено: ${_due.format(due)}' : _due.format(due),
      task.visibility.label,
      if (task.isHidden) 'скрыта организаторами',
    ].join(' · ');

    return InkWell(
      onTap: () => openTaskForm(context, task: task),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DSpace.xs),
        child: Row(
          children: [
            Semantics(
              button: true,
              checked: task.isDone,
              label: 'Сделано: ${task.title}',
              onTap: () => _toggle(context),
              excludeSemantics: true,
              child: InkResponse(
                onTap: () => _toggle(context),
                radius: 22,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    task.isDone
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.isDone ? c.accent : c.textTertiary,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: DSpace.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: t.body.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isDone ? c.textSecondary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: t.caption.copyWith(
                      color: task.isOverdue ? c.warning : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              switch (task.visibility) {
                TaskVisibility.public => Icons.public,
                TaskVisibility.internal => Icons.groups_outlined,
                TaskVisibility.private => Icons.lock_outline,
              },
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
