import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/goal.dart';
import 'package:dostigator/screens/checkin_screen.dart';
import 'package:dostigator/state/goals_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

/// Хранилище в памяти: настоящее лезет в Android Keystore, которого в тестах нет.
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
  // Сеть в тестах недоступна — фейковый контроллер её и не трогает.
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Перехватывает checkin: записывает аргументы и возвращает заданный
/// результат, не выходя в сеть. Так проверяем контракт экрана с API.
class _FakeGoalsController extends GoalsController {
  _FakeGoalsController(super.api);

  int calls = 0;
  int? lastGoalId;
  double? lastValue;
  String? lastComment;
  bool? lastNeedsHelp;

  /// null — успех; строка — текст ошибки, как в настоящем контроллере.
  String? result;

  @override
  Future<String?> checkin({
    required int goalId,
    required double value,
    String? comment,
    bool needsHelp = false,
  }) async {
    calls++;
    lastGoalId = goalId;
    lastValue = value;
    lastComment = comment;
    lastNeedsHelp = needsHelp;
    return result;
  }
}

Goal _goal({
  int progress = 50,
  bool hideValues = false,
  List<Map<String, dynamic>> checkins = const [],
}) {
  return Goal.fromJson({
    'id': 7,
    'title': 'Выйти на 1,5 млн чистыми',
    'metric': {
      'name': 'Чистая прибыль в месяц',
      'unit': '₽',
      'from': 900000,
      'target': 1500000,
      'current': 1200000,
    },
    'progress_percent': progress,
    'is_reached': false,
    'deadline': '2026-11-30',
    'days_left': 90,
    'status': 'active',
    'status_label': 'В работе',
    'visibility': 'group',
    'hide_absolute_values': hideValues,
    'checked_in_this_week': false,
    'missed_weeks': 0,
    'steps': const [],
    'checkins': checkins,
  });
}

/// Дата «неделю назад» относительно реальных часов: экран определяет
/// текущую неделю от DateTime.now(), фиксированная дата протухла бы.
String _isoDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Widget _wrap(GoalsController goals, {Goal? goal}) {
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
      // Экран открывается поверх заглушки, чтобы проверить pop после успеха.
      home: _Launcher(goal: goal),
    ),
  );
}

class _Launcher extends StatelessWidget {
  const _Launcher({this.goal});

  final Goal? goal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => CheckInScreen(goal: goal)),
          ),
          child: const Text('открыть'),
        ),
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  GoalsController goals, {
  Goal? goal,
}) async {
  // Форма длиннее тестового окна по умолчанию, а ListView строит только
  // видимое — без высокого окна нижние блоки не дойдут до отрисовки.
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(goals, goal: goal));
  await tester.tap(find.text('открыть'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  testWidgets('показывает контекст цели, прогресс и стартовое значение', (
    tester,
  ) async {
    final goals = _FakeGoalsController(_apiThatFails());
    await _open(tester, goals, goal: _goal());

    expect(find.text('Check-in недели'), findsOneWidget);
    expect(find.text('Зафиксируйте движение к цели'), findsOneWidget);
    expect(find.text('Выйти на 1,5 млн чистыми'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    // Чек-инов ещё нет — точка сравнения берётся из metric_from
    expect(find.textContaining('Старт:'), findsOneWidget);
    // Значение предзаполнено текущим значением метрики
    expect(find.text('1200000'), findsOneWidget);
  });

  testWidgets('прошлый чек-ин показывается как «Неделю назад»', (tester) async {
    final goals = _FakeGoalsController(_apiThatFails());
    final goal = _goal(
      checkins: [
        {
          'week_start': _isoDaysAgo(9),
          'metric_value': 1100000,
          'needs_help': false,
        },
      ],
    );
    await _open(tester, goals, goal: goal);

    expect(find.textContaining('Неделю назад:'), findsOneWidget);
    expect(find.textContaining('Старт:'), findsNothing);
  });

  /// Валидация: без числа нечего отправлять — запрос не должен уходить.
  testWidgets('пустое значение метрики не отправляется', (tester) async {
    final goals = _FakeGoalsController(_apiThatFails());
    await _open(tester, goals, goal: _goal());

    await tester.enterText(find.byKey(const ValueKey('checkin-value')), '');
    await tester.tap(find.text('Отправить check-in'));
    await tester.pump();

    expect(goals.calls, 0);
    expect(find.textContaining('Введите число'), findsOneWidget);
    // Экран остался открытым
    expect(find.byType(CheckInScreen), findsOneWidget);
  });

  testWidgets(
    'успешный submit отправляет данные, показывает snackbar и закрывает экран',
    (tester) async {
      final goals = _FakeGoalsController(_apiThatFails());
      await _open(tester, goals, goal: _goal());

      await tester.enterText(
        find.byKey(const ValueKey('checkin-value')),
        '1 300 000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('checkin-comment')),
        'Подписали двух клиентов',
      );
      await tester.tap(find.text('Отправить check-in'));
      await tester.pumpAndSettle();

      expect(goals.calls, 1);
      expect(goals.lastGoalId, 7);
      expect(goals.lastValue, 1300000);
      expect(goals.lastComment, 'Подписали двух клиентов');
      expect(goals.lastNeedsHelp, isFalse);

      expect(find.text('Check-in сохранён'), findsOneWidget);
      expect(find.byType(CheckInScreen), findsNothing);
    },
  );

  /// Stuck flag: поле помощи появляется по toggle, а его текст приклеивается
  /// к комментарию — API принимает только comment + needs_help.
  testWidgets('флаг «я застрял» открывает поле и уходит в запрос', (
    tester,
  ) async {
    final goals = _FakeGoalsController(_apiThatFails());
    await _open(tester, goals, goal: _goal());

    expect(find.byKey(const ValueKey('checkin-help')), findsNothing);

    await tester.tap(
      find.text('Я застрял — хочу разобрать это на мастермайнде'),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('checkin-help')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('checkin-comment')),
      'Воронка стоит',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkin-help')),
      'Не могу нанять РОПа',
    );
    await tester.tap(find.text('Отправить check-in'));
    await tester.pumpAndSettle();

    expect(goals.lastNeedsHelp, isTrue);
    expect(
      goals.lastComment,
      'Воронка стоит\nНужна помощь: Не могу нанять РОПа',
    );
  });

  /// Ошибка сервера: сообщение видно, экран не закрылся, данные целы.
  testWidgets('при ошибке данные не теряются', (tester) async {
    final goals = _FakeGoalsController(_apiThatFails())
      ..result = 'Сервер недоступен';
    await _open(tester, goals, goal: _goal());

    await tester.enterText(
      find.byKey(const ValueKey('checkin-value')),
      '1250000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('checkin-comment')),
      'Запустили рекламу',
    );
    await tester.tap(find.text('Отправить check-in'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckInScreen), findsOneWidget);
    expect(find.text('Сервер недоступен'), findsOneWidget);
    expect(find.text('1250000'), findsOneWidget);
    expect(find.text('Запустили рекламу'), findsOneWidget);
    expect(find.text('Check-in сохранён'), findsNothing);
  });

  /// Приватность прячет суммы от чужих глаз, но своё значение вводится
  /// как обычно — экран обязан объяснить это подписью.
  testWidgets('при скрытых суммах поле работает и есть пояснение', (
    tester,
  ) async {
    final goals = _FakeGoalsController(_apiThatFails());
    await _open(tester, goals, goal: _goal(hideValues: true));

    expect(find.byKey(const ValueKey('checkin-value')), findsOneWidget);
    expect(find.text('Абсолютное значение видно только вам'), findsOneWidget);
  });

  testWidgets('без цели показывается пустое состояние, а не форма', (
    tester,
  ) async {
    final goals = _FakeGoalsController(_apiThatFails());
    await _open(tester, goals);

    expect(find.text('Поставьте первую цель'), findsOneWidget);
    expect(find.text('Отправить check-in'), findsNothing);
  });
}
