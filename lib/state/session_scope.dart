import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import 'auth_controller.dart';
import 'directory_controller.dart';
import 'events_controller.dart';
import 'goals_controller.dart';
import 'habits_controller.dart';
import 'knowledge_controller.dart';
import 'mastermind_controller.dart';
import 'plan_controller.dart';
import 'tasks_controller.dart';

/// Данные одного входа: цели, привычки, задачи, план, события, группа, каталог.
///
/// Выход из аккаунта выбрасывает их целиком и создаёт пустые заново —
/// следующий человек на этом телефоне не увидит ни чужих билетов,
/// ни чужих целей, даже на долю секунды до первой загрузки.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.api, required this.child});

  final ApiClient api;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthController, bool>(
      (auth) => auth.stage == AuthStage.signedIn,
    );

    return MultiProvider(
      // Новый ключ — новые контроллеры; старые провайдер закроет сам
      key: ValueKey(signedIn),
      providers: [
        ChangeNotifierProvider(create: (_) => GoalsController(api)),
        ChangeNotifierProvider(create: (_) => MastermindController(api)),
        ChangeNotifierProvider(create: (_) => EventsController(api)),
        ChangeNotifierProvider(create: (_) => DirectoryController(api)),
        ChangeNotifierProvider(create: (_) => HabitsController(api)),
        ChangeNotifierProvider(create: (_) => TasksController(api)),
        ChangeNotifierProvider(create: (_) => PlanController(api)),
        ChangeNotifierProvider(create: (_) => KnowledgeController(api)),
      ],
      child: child,
    );
  }
}
