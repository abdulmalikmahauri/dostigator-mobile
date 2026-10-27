import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/formatting.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/goal.dart';
import 'package:dostigator/screens/goal_create_screen.dart';
import 'package:dostigator/state/goals_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

/// Хранилище в памяти: настоящее лезет в Android Keystore,
/// которого в тестах нет.
class _FakeStorage extends TokenStorage {
  _FakeStorage() : super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

ApiClient _apiThatFails() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Контроллер без сети. create всегда завершается ошибкой: успех повёл бы
/// экран в Reminders (платформенный плагин), которого в тестовой среде нет.
class _FakeGoalsController extends GoalsController {
  _FakeGoalsController() : super(_apiThatFails());

  int createCalls = 0;
  Map<String, Object?>? lastCreate;

  /// Если задан — create ждёт его завершения (для проверки loading-состояния).
  Completer<String?>? pending;

  String createError = 'Сервер недоступен';

  @override
  Future<String?> create({
    required String title,
    String? why,
    required String metricName,
    String? metricUnit,
    required double from,
    required double target,
    required DateTime deadline,
    List<String> steps = const [],
    bool hideAbsoluteValues = false,
  }) async {
    createCalls++;
    lastCreate = {
      'title': title,
      'why': why,
      'metricName': metricName,
      'metricUnit': metricUnit,
      'from': from,
      'target': target,
      'deadline': deadline,
      'steps': steps,
      'hideAbsoluteValues': hideAbsoluteValues,
    };

    if (pending != null) return pending!.future;
    return createError;
  }

  int updateCalls = 0;
  int? updatedGoalId;
  Map<String, Object?>? lastUpdate;

  @override
  Future<String?> update({
    required int goalId,
    required String title,
    String? why,
    required String metricName,
    String? metricUnit,
    required double from,
    required double target,
    required DateTime deadline,
    List<GoalStepDraft> steps = const [],
    bool hideAbsoluteValues = false,
  }) async {
    updateCalls++;
    updatedGoalId = goalId;
    lastUpdate = {
      'title': title,
      'deadline': deadline,
      'steps': [for (final s in steps) s.toJson()],
      'hideAbsoluteValues': hideAbsoluteValues,
    };

    return 'Сервер недоступен';
  }

  final closed = <(int, String)>[];

  @override
  Future<String?> close(int goalId, String status) async {
    closed.add((goalId, status));

    return 'Сервер недоступен';
  }

  @override
  Future<void> load({bool silent = false}) async {}
}

Widget _wrap(Widget child, GoalsController goals) {
  return ChangeNotifierProvider<GoalsController>.value(
    value: goals,
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

Future<_FakeGoalsController> _pumpScreen(
  WidgetTester tester, {
  Goal? goal,
}) async {
  // Форма длиннее тестового окна, а ListView строит только видимое —
  // без высокого окна нижние поля просто не дойдут до отрисовки.
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final goals = _FakeGoalsController();
  await tester.pumpWidget(_wrap(GoalCreateScreen(goal: goal), goals));
  await tester.pump();
  return goals;
}

/// Цель, которую открывают на правку: два шага, первый уже сделан.
Goal _existingGoal() {
  return Goal.fromJson({
    'id': 7,
    'title': 'Открыть третью кофейню',
    'why': 'Хочу сеть',
    'metric': {
      'name': 'Точек в сети',
      'unit': 'шт',
      'from': 2,
      'target': 3,
      'current': 2,
    },
    'progress_percent': 0,
    'is_reached': false,
    'deadline': '2030-06-30',
    'days_left': 900,
    'status': 'active',
    'status_label': 'В работе',
    'is_main': true,
    'visibility': 'group',
    'hide_absolute_values': true,
    'checked_in_this_week': false,
    'missed_weeks': 0,
    'steps': [
      {'id': 11, 'title': 'Найти помещение', 'is_done': true},
      {'id': 12, 'title': 'Нанять бариста', 'is_done': false},
    ],
    'checkins': const [],
  });
}

/// Срок по умолчанию — три месяца от сегодня. Правило продублировано
/// сознательно: тест фиксирует его, а не переиспользует реализацию.
DateTime _expectedDeadline(DateTime now) {
  return DateTime(now.year, now.month + 3, now.day);
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('goal-title')),
    'Выйти на 1,5 млн чистыми',
  );
  await tester.enterText(
    find.byKey(const Key('metric-name')),
    'Чистая прибыль в месяц',
  );
  await tester.enterText(find.byKey(const Key('metric-from')), '900000');
  await tester.enterText(find.byKey(const Key('metric-target')), '1500000');
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  testWidgets('экран показывает форму цели и кнопку сохранения', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Новая цель'), findsOneWidget);
    expect(find.text('Название цели'), findsOneWidget);
    expect(find.text('Показатель'), findsOneWidget);
    expect(find.text('Сейчас'), findsOneWidget);
    expect(find.text('Станет'), findsOneWidget);
    expect(find.text('Сохранить цель'), findsOneWidget);
    expect(
      find.text('Скрыть абсолютные значения от участников'),
      findsOneWidget,
    );
  });

  testWidgets('срок по умолчанию — через три месяца', (tester) async {
    await _pumpScreen(tester);

    expect(
      find.text(Fmt.date(_expectedDeadline(DateTime.now()))),
      findsOneWidget,
    );
  });

  /// Пустая форма не должна отправляться: иначе на сервер уходит запрос,
  /// который заведомо вернёт ошибку.
  testWidgets('пустая форма не отправляется, ошибки под полями', (
    tester,
  ) async {
    final goals = await _pumpScreen(tester);

    await tester.tap(find.text('Сохранить цель'));
    await tester.pump();

    expect(find.text('Сформулируйте цель'), findsOneWidget);
    expect(find.text('Укажите показатель'), findsOneWidget);
    expect(goals.createCalls, 0);
  });

  /// Цель «из 900 000 в 900 000» не цель: без разницы значений
  /// прогресс не посчитать.
  testWidgets('целевое значение обязано отличаться от текущего', (
    tester,
  ) async {
    final goals = await _pumpScreen(tester);

    await _fillValidForm(tester);
    await tester.enterText(find.byKey(const Key('metric-target')), '900000');

    await tester.tap(find.text('Сохранить цель'));
    await tester.pump();

    expect(find.text('Должно отличаться'), findsOneWidget);
    expect(goals.createCalls, 0);
  });

  testWidgets('подсказка «было → станет» форматируется через Fmt', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('metric-from')), '900000');
    await tester.enterText(find.byKey(const Key('metric-target')), '1500000');
    await tester.enterText(find.byKey(const Key('metric-unit')), '₽');
    await tester.pump();

    expect(
      find.text('${Fmt.metric(900000, '₽')} → ${Fmt.metric(1500000, '₽')}'),
      findsOneWidget,
    );
  });

  testWidgets('шаги можно добавлять и удалять', (tester) async {
    await _pumpScreen(tester);

    expect(find.byKey(const Key('step-0')), findsOneWidget);
    expect(find.byKey(const Key('step-1')), findsNothing);

    await tester.tap(find.byKey(const Key('add-step')));
    await tester.pump();
    expect(find.byKey(const Key('step-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-step-1')));
    await tester.pump();
    expect(find.byKey(const Key('step-1')), findsNothing);
    // Последний шаг удалить нельзя — кнопки удаления нет
    expect(find.byKey(const Key('remove-step-0')), findsNothing);
  });

  /// Раньше полей шагов было не больше восьми.
  testWidgets('шагов можно добавить сколько нужно', (tester) async {
    await _pumpScreen(tester);

    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const Key('add-step')));
      await tester.pump();
    }

    expect(find.byKey(const Key('step-11')), findsOneWidget);
    expect(find.byKey(const Key('add-step')), findsOneWidget);
  });

  /// Кнопка стоит последней строкой формы и уезжает вместе с ней,
  /// а не висит поверх клавиатуры, закрывая поля.
  testWidgets('кнопка сохранения — в самом низу формы, а не поверх неё', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Сохранить цель'),
      ),
      findsOneWidget,
    );

    final button = tester.getTopLeft(find.text('Сохранить цель')).dy;
    final lastField = tester.getTopLeft(find.byKey(const Key('step-0'))).dy;
    expect(button, greaterThan(lastField));
  });

  group('Правка цели', () {
    testWidgets('форма открывается заполненной', (tester) async {
      await _pumpScreen(tester, goal: _existingGoal());

      expect(find.text('Правка цели'), findsOneWidget);
      expect(find.text('Открыть третью кофейню'), findsOneWidget);
      expect(find.text('Точек в сети'), findsOneWidget);
      expect(find.text('Найти помещение'), findsOneWidget);
      expect(find.text('Нанять бариста'), findsOneWidget);
      expect(find.text(Fmt.date(DateTime(2030, 6, 30))), findsOneWidget);

      final toggle = tester.widget<Switch>(
        find.byKey(const Key('privacy-toggle')),
      );
      expect(toggle.value, isTrue);
    });

    /// По id сервер отличает переименованный шаг от нового —
    /// и не теряет отметку «сделано».
    testWidgets('сохранение шлёт правку с номерами прежних шагов', (
      tester,
    ) async {
      final goals = await _pumpScreen(tester, goal: _existingGoal());

      await tester.enterText(
        find.byKey(const Key('goal-title')),
        'Открыть третью и четвёртую',
      );
      await tester.enterText(find.byKey(const Key('step-1')), 'Нанять двоих');
      await tester.tap(find.byKey(const Key('add-step')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('step-2')), 'Запустить');

      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(goals.createCalls, 0);
      expect(goals.updateCalls, 1);
      expect(goals.updatedGoalId, 7);
      expect(goals.lastUpdate?['title'], 'Открыть третью и четвёртую');
      expect(goals.lastUpdate?['deadline'], DateTime(2030, 6, 30));
      expect(goals.lastUpdate?['steps'], [
        {'id': 11, 'title': 'Найти помещение'},
        {'id': 12, 'title': 'Нанять двоих'},
        {'title': 'Запустить'},
      ]);
    });

    testWidgets('удалённый шаг в правку не уходит', (tester) async {
      final goals = await _pumpScreen(tester, goal: _existingGoal());

      await tester.tap(find.byKey(const Key('remove-step-0')));
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await tester.pump();

      expect(goals.lastUpdate?['steps'], [
        {'id': 12, 'title': 'Нанять бариста'},
      ]);
    });

    testWidgets('цель можно завершить прямо из формы', (tester) async {
      final goals = await _pumpScreen(tester, goal: _existingGoal());

      await tester.tap(find.text('Завершить цель'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Цель достигнута'));
      await tester.pump();

      expect(goals.closed, [(7, 'achieved')]);
    });

    testWidgets('у новой цели завершать нечего', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Завершить цель'), findsNothing);
    });
  });

  testWidgets('privacy-переключатель уходит в запрос', (tester) async {
    final goals = await _pumpScreen(tester);

    await _fillValidForm(tester);
    await tester.tap(find.byKey(const Key('privacy-toggle')));
    await tester.pump();

    await tester.tap(find.text('Сохранить цель'));
    await tester.pump();

    expect(goals.createCalls, 1);
    expect(goals.lastCreate?['hideAbsoluteValues'], isTrue);
  });

  /// Ошибка сервера не должна стирать введённое: резидент правит
  /// одно поле, а не набирает цель заново.
  testWidgets('ошибка сервера показывается, форма сохраняет данные', (
    tester,
  ) async {
    final goals = await _pumpScreen(tester);
    goals.createError = 'Не удалось сохранить цель';

    await _fillValidForm(tester);
    await tester.tap(find.text('Сохранить цель'));
    await tester.pump();

    expect(find.text('Не удалось сохранить цель'), findsOneWidget);
    expect(find.text('Выйти на 1,5 млн чистыми'), findsOneWidget);
    expect(find.text('900000'), findsOneWidget);
  });

  testWidgets('во время запроса кнопка в loading и повторный tap запрещён', (
    tester,
  ) async {
    final goals = await _pumpScreen(tester);
    goals.pending = Completer<String?>();

    await _fillValidForm(tester);
    await tester.tap(find.text('Сохранить цель'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    // Повторный tap во время запроса не создаёт вторую цель
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(goals.createCalls, 1);

    goals.pending!.complete('Сервер недоступен');
    await tester.pump();
    expect(find.text('Сервер недоступен'), findsOneWidget);
  });
}
