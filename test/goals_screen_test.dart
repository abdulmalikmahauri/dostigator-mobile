import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/goal.dart';
import 'package:dostigator/models/resident.dart';
import 'package:dostigator/screens/goal_create_screen.dart';
import 'package:dostigator/screens/goal_detail_screen.dart';
import 'package:dostigator/screens/goals_archive_screen.dart';
import 'package:dostigator/screens/planner_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/goals_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/theme.dart';

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
  // Сеть в тестах недоступна — важно, что экраны это переживают
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

Goal _goal({
  int id = 1,
  String title = 'Выйти на 1,5 млн чистыми',
  String status = 'active',
  String statusLabel = 'В работе',
  bool isMain = false,
  bool checkedIn = false,
  int progress = 50,
  bool reached = false,
  bool hideValues = false,
  String deadline = '2026-11-30',
  int daysLeft = 90,
  List<Map<String, dynamic>> steps = const [],
  List<Map<String, dynamic>> checkins = const [],
}) {
  return Goal.fromJson({
    'id': id,
    'title': title,
    'why': 'Нанять управляющего',
    'metric': {
      'name': 'Чистая прибыль в месяц',
      'unit': '₽',
      'from': 900000,
      'target': 1500000,
      'current': 1200000,
    },
    'progress_percent': progress,
    'is_reached': reached,
    'deadline': deadline,
    'days_left': daysLeft,
    'status': status,
    'status_label': statusLabel,
    'is_main': isMain,
    'visibility': 'group',
    'hide_absolute_values': hideValues,
    'checked_in_this_week': checkedIn,
    'missed_weeks': 0,
    'steps': steps,
    'checkins': checkins,
  });
}

Resident _resident() {
  return Resident.fromJson({
    'id': 1,
    'name': 'Али-Бек Мусаев',
    'phone': '+79000000001',
    'phone_pretty': '+7 900 000-00-01',
    'card_number': 'DG-00001',
    'tier_label': 'Бизнес-клуб',
    'is_club_member': true,
    'city': 'Грозный',
    'memberships': const [],
  });
}

Widget _wrap(Widget child, {required GoalsController goals, ApiClient? api}) {
  final client = api ?? _apiThatFails();

  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: client, tokens: _FakeStorage())
          ..resident = _resident(),
      ),
      ChangeNotifierProvider<GoalsController>.value(value: goals),
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

/// Экран длиннее тестового окна, а ListView строит только видимое —
/// без высокого окна нижние блоки не дойдут до отрисовки.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3800);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  group('Цели — активная цель', () {
    testWidgets('видны название, метрика, прогресс, срок и архив', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)..goals = [_goal()];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Планер'), findsOneWidget);
      expect(find.text('Выйти на 1,5 млн чистыми'), findsOneWidget);
      // Метрика было → сейчас → цель
      expect(find.text('было'), findsOneWidget);
      expect(find.text('сейчас'), findsOneWidget);
      expect(find.text('цель'), findsOneWidget);
      // Процент на кольце и срок
      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('осталось'), findsOneWidget);
      // Архив доступен всегда
      expect(find.text('Архив целей'), findsOneWidget);
    });

    testWidgets('приватная цель скрывает абсолютные значения', (tester) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)..goals = [_goal(hideValues: true)];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('было'), findsNothing);
      expect(find.text('сейчас'), findsNothing);
      expect(find.text('цель'), findsNothing);
      // Процент остаётся: он не раскрывает абсолютных величин
      expect(find.text('50%'), findsOneWidget);
      expect(find.textContaining('Абсолютные значения скрыты'), findsOneWidget);
    });

    testWidgets('шаги показывают статусы по порядку выполнения', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)
        ..goals = [
          _goal(
            steps: [
              {
                'id': 1,
                'title': 'Подготовить стратегию роста',
                'is_done': true,
              },
              {'id': 2, 'title': 'Найти 3 новых партнёра', 'is_done': false},
              {'id': 3, 'title': 'Расширить отдел продаж', 'is_done': false},
            ],
          ),
        ];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Подготовить стратегию роста'), findsOneWidget);
      // Первый — выполнен, следующий — текущий, остальные — запланированы
      expect(find.text('Выполнено'), findsOneWidget);
      expect(find.text('В процессе'), findsOneWidget);
      expect(find.text('Запланировано'), findsOneWidget);
    });

    testWidgets('достигнутая цель получает статус «Цель достигнута»', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)
        ..goals = [_goal(progress: 100, reached: true)];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Цель достигнута'), findsOneWidget);
      // Срок больше не подгоняет
      expect(find.textContaining('осталось'), findsNothing);
    });
  });

  group('Цели — check-in', () {
    testWidgets('без отчёта видна кнопка «Заполнить»', (tester) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)..goals = [_goal()];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Подведите итоги недели'), findsOneWidget);
      expect(find.text('Заполнить'), findsOneWidget);
    });

    testWidgets('после отчёта — «Выполнено» и «Посмотреть отчёт»', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)..goals = [_goal(checkedIn: true)];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Отчёт за эту неделю отправлен'), findsOneWidget);
      expect(find.text('Выполнено'), findsOneWidget);
      expect(find.text('Посмотреть отчёт'), findsOneWidget);
      expect(find.text('Заполнить'), findsNothing);
    });
  });

  group('Цели — несколько целей', () {
    GoalsController twoGoals() => GoalsController(_apiThatFails())
      ..goals = [
        _goal(id: 1, title: 'Открыть третью кофейню', isMain: true),
        _goal(id: 2, title: 'Пробежать полумарафон', progress: 30),
      ];

    testWidgets('главная развёрнута, остальные — строками ниже', (
      tester,
    ) async {
      _tallWindow(tester);
      await tester.pumpWidget(_wrap(const PlannerScreen(), goals: twoGoals()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ГЛАВНАЯ ЦЕЛЬ'), findsOneWidget);
      expect(find.text('Открыть третью кофейню'), findsOneWidget);
      expect(find.text('ДРУГИЕ ЦЕЛИ'), findsOneWidget);
      expect(find.text('Пробежать полумарафон'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
    });

    testWidgets('одна цель — без слова «главная» и без списка других', (
      tester,
    ) async {
      _tallWindow(tester);
      final goals = GoalsController(_apiThatFails())
        ..goals = [_goal(isMain: true)];

      await tester.pumpWidget(_wrap(const PlannerScreen(), goals: goals));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('МОЯ ЦЕЛЬ'), findsOneWidget);
      expect(find.text('ГЛАВНАЯ ЦЕЛЬ'), findsNothing);
      expect(find.text('ДРУГИЕ ЦЕЛИ'), findsNothing);
    });

    /// Раньше кнопка была только при пустом экране: вторую цель
    /// поставить было нельзя, пока не закрыта первая.
    testWidgets('новую цель можно поставить, не закрывая прежнюю', (
      tester,
    ) async {
      _tallWindow(tester);
      await tester.pumpWidget(_wrap(const PlannerScreen(), goals: twoGoals()));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Новая цель'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GoalCreateScreen), findsOneWidget);
    });

    testWidgets('строка другой цели открывает её целиком', (tester) async {
      _tallWindow(tester);
      await tester.pumpWidget(_wrap(const PlannerScreen(), goals: twoGoals()));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Пробежать полумарафон'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GoalDetailScreen), findsOneWidget);
      expect(find.text('Сделать главной'), findsOneWidget);
    });

    testWidgets('у цели есть вход в правку', (tester) async {
      _tallWindow(tester);
      await tester.pumpWidget(_wrap(const PlannerScreen(), goals: twoGoals()));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Изменить цель'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GoalCreateScreen), findsOneWidget);
      // Форма открылась уже заполненной
      expect(find.text('Правка цели'), findsOneWidget);
      expect(find.text('Открыть третью кофейню'), findsOneWidget);
    });
  });

  group('Цели — пусто', () {
    testWidgets('без цели предлагается её поставить', (tester) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)..goals = [];

      await tester.pumpWidget(
        _wrap(const PlannerScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Поставьте первую цель'), findsOneWidget);
      expect(find.text('Поставить цель'), findsOneWidget);
      // Архив остаётся доступен и без активной цели
      expect(find.text('Архив целей'), findsOneWidget);
    });
  });

  group('Архив целей — архивный квартал', () {
    testWidgets('карточка квартала: квартал, название, итог и статус', (
      tester,
    ) async {
      final api = _apiThatFails();
      final goals = GoalsController(api)
        ..goals = [
          _goal(),
          _goal(
            id: 2,
            title: 'Запустить новое направление',
            status: 'done',
            statusLabel: 'Завершена',
            progress: 74,
            deadline: '2025-12-28',
          ),
        ];

      await tester.pumpWidget(
        _wrap(const GoalsArchiveScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      // Активная цель в архив не попадает
      expect(find.text('Выйти на 1,5 млн чистыми'), findsNothing);

      expect(find.text('СРОК ДО 28 ДЕКАБРЯ 2025'), findsOneWidget);
      expect(find.text('Запустить новое направление'), findsOneWidget);
      expect(find.text('74%'), findsOneWidget);
      expect(find.text('Завершена'), findsOneWidget);
    });

    testWidgets('деталь архивной цели read-only: метрика, шаги и история', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)
        ..goals = [
          _goal(
            id: 2,
            title: 'Запустить новое направление',
            status: 'done',
            statusLabel: 'Завершена',
            progress: 74,
            deadline: '2025-12-28',
            steps: [
              {'id': 1, 'title': 'Собрать команду', 'is_done': true},
              {'id': 2, 'title': 'Выйти на первую сделку', 'is_done': false},
            ],
            checkins: [
              {
                'week_start': '2025-10-13',
                'metric_value': 1200000,
                'needs_help': false,
                'comment': 'Подписали двух клиентов',
              },
              {
                'week_start': '2025-10-06',
                'metric_value': 1000000,
                'needs_help': true,
                'comment': null,
              },
            ],
          ),
        ];

      await tester.pumpWidget(
        _wrap(const GoalsArchiveScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Запустить новое направление'));
      await tester.pumpAndSettle();

      expect(find.text('итоговый прогресс'), findsOneWidget);
      expect(find.text('74%'), findsOneWidget);
      // Метрика с подписью «итог» вместо «сейчас»
      expect(find.text('итог'), findsOneWidget);
      // Шаги закрытого квартала: без «В процессе», нажатий нет
      expect(find.text('Выполнено'), findsOneWidget);
      expect(find.text('Не выполнено'), findsOneWidget);
      expect(find.text('В процессе'), findsNothing);
      // История check-in: дата — % — комментарий, по ходу квартала
      expect(find.text('Подписали двух клиентов'), findsOneWidget);
      expect(find.text('Нужна помощь'), findsOneWidget);
      // 1 000 000 из 900 000 → 1 500 000 = 17%, 1 200 000 = 50%
      expect(find.text('17%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('приватность сохраняется и в архиве', (tester) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final goals = GoalsController(api)
        ..goals = [
          _goal(
            id: 2,
            status: 'done',
            statusLabel: 'Завершена',
            hideValues: true,
            deadline: '2025-12-28',
          ),
        ];

      await tester.pumpWidget(
        _wrap(const GoalsArchiveScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Выйти на 1,5 млн чистыми'));
      await tester.pumpAndSettle();

      expect(find.text('было'), findsNothing);
      expect(find.text('итог'), findsNothing);
      expect(find.textContaining('Абсолютные значения скрыты'), findsOneWidget);
    });

    testWidgets('без завершённых кварталов — объясняющая заглушка', (
      tester,
    ) async {
      final api = _apiThatFails();
      final goals = GoalsController(api)..goals = [_goal()];

      await tester.pumpWidget(
        _wrap(const GoalsArchiveScreen(), goals: goals, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('История появится, когда вы завершите первую цель'),
        findsOneWidget,
      );
    });
  });
}
