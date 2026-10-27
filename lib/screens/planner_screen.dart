import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/spacing.dart';
import '../state/goals_controller.dart';
import '../state/habits_controller.dart';
import '../state/plan_controller.dart';
import '../state/tasks_controller.dart';
import '../widgets/d_app_scaffold.dart';
import '../widgets/d_segmented.dart';
import 'goals_screen.dart';
import 'habits_view.dart';
import 'plan_view.dart';
import 'tasks_view.dart';

enum _Tab { goals, habits, tasks, plan }

/// Вкладка «Планер»: цели, привычки, задачи и план по дням —
/// переключателем вверху. Разделы грузятся, когда их открыли.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with WidgetsBindingObserver {
  _Tab _tab = _Tab.goals;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Вернулись в приложение — возможно, уже наступил новый день:
  /// привычки и план без обновления показали бы вчерашнее «сегодня».
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    switch (_tab) {
      case _Tab.habits:
        context.read<HabitsController>().load(silent: true);
      case _Tab.plan:
        context.read<PlanController>().load(silent: true);
      case _Tab.goals || _Tab.tasks:
        break;
    }
  }

  void _switch(_Tab tab) {
    setState(() => _tab = tab);

    switch (tab) {
      case _Tab.goals:
        break;
      case _Tab.habits:
        final habits = context.read<HabitsController>();
        if (!habits.loaded && !habits.loading) habits.load();
      case _Tab.tasks:
        final tasks = context.read<TasksController>();
        if (!tasks.loaded && !tasks.loading) tasks.load();
      case _Tab.plan:
        // План собирается из всего остального — свежим он нужен всегда
        final plan = context.read<PlanController>();
        plan.load(silent: plan.loaded);
    }
  }

  Future<void> _refresh() => switch (_tab) {
    _Tab.goals => context.read<GoalsController>().load(silent: true),
    _Tab.habits => context.read<HabitsController>().load(silent: true),
    _Tab.tasks => context.read<TasksController>().load(silent: true),
    _Tab.plan => context.read<PlanController>().load(silent: true),
  };

  @override
  Widget build(BuildContext context) {
    return DAppScaffold(
      title: 'Планер',
      subtitle: 'Цели. Привычки. Задачи.',
      onRefresh: _refresh,
      children: [
        DSegmented<_Tab>(
          segments: const [
            (_Tab.goals, 'Цели'),
            (_Tab.habits, 'Привычки'),
            (_Tab.tasks, 'Задачи'),
            (_Tab.plan, 'План'),
          ],
          selected: _tab,
          onChanged: _switch,
        ),
        const SizedBox(height: DSpace.section),
        switch (_tab) {
          _Tab.goals => const GoalsView(),
          _Tab.habits => const HabitsView(),
          _Tab.tasks => const TasksView(),
          _Tab.plan => const PlanView(),
        },
      ],
    );
  }
}
