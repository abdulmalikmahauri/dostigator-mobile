import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/habit.dart';
import 'package:dostigator/models/task.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/goals_controller.dart';
import 'package:dostigator/state/habits_controller.dart';
import 'package:dostigator/state/plan_controller.dart';
import 'package:dostigator/state/tasks_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'planner.dart';
import 'theme.dart';

/// Контроллеры без сети: экраны зовут загрузку сами, а тест заранее
/// кладёт данные и потом смотрит, что экран попросил сделать.
class StubGoalsController extends GoalsController {
  StubGoalsController(super.api);

  @override
  Future<void> load({bool silent = false}) async {}
}

class StubHabitsController extends HabitsController {
  StubHabitsController(super.api);

  final List<(int, DateTime, int)> logged = [];
  final List<HabitDraft> created = [];
  final List<(int, int)> joined = [];
  List<ListedHabit> suggestions = const [];
  List<ListedHabit> catalogResult = const [];
  int loads = 0;

  @override
  Future<void> load({bool silent = false}) async => loads++;

  @override
  Future<String?> log(int id, DateTime date, int value) async {
    logged.add((id, date, value));
    return null;
  }

  @override
  Future<Habit> create(HabitDraft draft) async {
    created.add(draft);
    return Habit.fromJson(habitJson(title: draft.title));
  }

  @override
  Future<List<ListedHabit>> suggest(String title) async => suggestions;

  @override
  Future<List<ListedHabit>> catalog({String? query}) async => catalogResult;

  @override
  Future<Habit> join(int id, int target) async {
    joined.add((id, target));
    return Habit.fromJson(habitJson(id: id, target: target));
  }

  @override
  Future<Habit> detail(int id) async => habits.firstWhere((h) => h.id == id);

  @override
  Future<List<HabitRatingRow>> rating() async => const [];
}

class StubTasksController extends TasksController {
  StubTasksController(super.api);

  final List<int> toggled = [];
  final List<TaskDraft> created = [];

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<String?> toggle(int id) async {
    toggled.add(id);
    return null;
  }

  @override
  Future<Task> create(TaskDraft draft) async {
    created.add(draft);
    return Task.fromJson(taskJson(title: draft.title));
  }
}

class StubPlanController extends PlanController {
  StubPlanController(super.api);

  @override
  Future<bool> load({bool silent = false}) async => true;
}

class PlannerStubs {
  PlannerStubs([ApiClient? api]) : api = api ?? unreachableApi();

  final ApiClient api;
  late final goals = StubGoalsController(api);
  late final habits = StubHabitsController(api);
  late final tasks = StubTasksController(api);
  late final plan = StubPlanController(api);
}

Widget wrapPlanner(Widget child, PlannerStubs s) {
  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: s.api),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: s.api, tokens: MemoryTokenStorage()),
      ),
      ChangeNotifierProvider<GoalsController>.value(value: s.goals),
      ChangeNotifierProvider<HabitsController>.value(value: s.habits),
      ChangeNotifierProvider<TasksController>.value(value: s.tasks),
      ChangeNotifierProvider<PlanController>.value(value: s.plan),
    ],
    child: MaterialApp(
      theme: buildDostigatorTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void tallPlannerWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}
