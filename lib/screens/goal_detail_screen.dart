import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/spacing.dart';
import '../design/typography.dart';
import '../state/goals_controller.dart';
import '../widgets/d_states.dart';
import '../widgets/d_sub_scaffold.dart';
import 'goals_screen.dart';

/// Одна цель целиком — для тех, что стоят на вкладке строкой ниже главной.
///
/// Экран получает номер цели, а не саму цель: после чек-ина или правки
/// контроллер перечитывает список, и здесь сразу видно свежее.
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsController>();
    final goal = goals.byId(goalId);

    if (goal == null || !goal.isActive) {
      // Цель закрыли, пока экран был открыт, — честно говорим, где её искать
      return const DSubScaffold(
        title: 'Цель',
        children: [
          DEmptyState(
            title: 'Цель завершена',
            message: 'Она переехала в архив целей.',
          ),
        ],
      );
    }

    return DSubScaffold(
      title: 'Цель',
      onRefresh: () => goals.load(silent: true),
      children: [
        GoalBlocks(goal: goal, label: goal.isMain ? 'Главная цель' : 'Цель'),
        if (!goal.isMain) ...[
          const SizedBox(height: DSpace.section),
          OutlinedButton(
            onPressed: goals.busy ? null : () => _makeMain(context),
            child: const Text('Сделать главной'),
          ),
          const SizedBox(height: DSpace.sm),
          Text(
            'Главную цель видит ваша группа, и её первой показывает Пульс.',
            style: DText.of(context).caption,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _makeMain(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<GoalsController>().makeMain(goalId);

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Теперь это главная цель')),
    );
  }
}
