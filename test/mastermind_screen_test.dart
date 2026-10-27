import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/mastermind.dart';
import 'package:dostigator/screens/mastermind_screen.dart';
import 'package:dostigator/screens/protocol_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/mastermind_controller.dart';
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
  // Сеть в тестах недоступна — данные подкладываются в фейковый контроллер
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));

  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Контроллер без сети: load() ничего не делает, данные задаются полями,
/// а вызовы действий записываются для проверки.
class _FakeMastermind extends MastermindController {
  _FakeMastermind() : super(_apiThatFails());

  int? toggledId;
  int? requestedSessionId;
  MastermindSession? sessionToReturn;

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<String?> toggleCommitment(int id) async {
    toggledId = id;

    return null;
  }

  @override
  Future<MastermindSession?> loadSession(int id) async {
    requestedSessionId = id;

    return sessionToReturn;
  }
}

MastermindGroup _group({
  bool isCurator = false,
  bool withNext = true,
  Map<String, dynamic>? lastSession,
}) {
  return MastermindGroup.fromJson({
    'id': 1,
    'name': 'Группа Альфа',
    'is_curator': isCurator,
    'curator': {'id': 9, 'name': 'Али-Бек Мусаев'},
    'members': [
      {
        'id': 1,
        'name': 'Аслан Демидов',
        'business': 'Склад-Сервис',
        'is_me': true,
        'public_status': 'on_focus',
        'public_status_label': 'В фокусе',
      },
      {
        'id': 2,
        'name': 'Адам Глебов',
        'business': 'Сеть кофеен',
        'is_me': false,
        'public_status': 'needs_help',
        'public_status_label': 'Нужна помощь',
      },
      // Без цели сервер отдаёт null — у строки не должно быть чипа
      {'id': 3, 'name': 'Магомед Ильин', 'is_me': false},
    ],
    'members_count': 3,
    'next_session': withNext
        ? {
            'id': 5,
            'scheduled_at': '2026-09-20T19:00:00+03:00',
            'place': 'Офис в центре',
            'status': 'agenda_ready',
            'has_agenda': true,
          }
        : null,
    'last_session': lastSession,
  });
}

MastermindSession _session({
  required bool isCurator,
  List<Map<String, dynamic>> agenda = const [],
  Map<String, int> summary = const {},
  List<Map<String, dynamic>> commitments = const [],
  List<Map<String, dynamic>> attendance = const [],
  String status = 'agenda_ready',
  String? notes,
}) {
  return MastermindSession.fromJson({
    'id': 5,
    'group_name': 'Группа Альфа',
    'scheduled_at': '2026-09-20T19:00:00+03:00',
    'place': 'Офис в центре',
    'status': status,
    'is_curator': isCurator,
    'notes': notes,
    'agenda': agenda,
    'agenda_summary': summary,
    'commitments': commitments,
    'attendance': attendance,
  });
}

Widget _wrap(Widget child, MastermindController mastermind) {
  final api = _apiThatFails();

  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: api, tokens: _FakeStorage()),
      ),
      ChangeNotifierProvider<MastermindController>.value(value: mastermind),
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
      // В приложении Scaffold даёт home_shell — здесь он нужен
      // для snackbar-ов и корректной высоты вьюпорта
      home: Scaffold(body: child),
    ),
  );
}

/// Экран длиннее тестового окна, а ListView строит только видимое —
/// без высокого вьюпорта нижние блоки просто не отрисуются.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  group('Группа: нет группы', () {
    testWidgets('показывается причина сервера', (tester) async {
      final c = _FakeMastermind()
        ..unavailableReason = 'Мастермайнды доступны резидентам бизнес-клуба';

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Группа пока не назначена'), findsOneWidget);
      expect(
        find.text('Мастермайнды доступны резидентам бизнес-клуба'),
        findsOneWidget,
      );
    });

    testWidgets('без причины — запасной текст раздела 31', (tester) async {
      await tester.pumpWidget(
        _wrap(const MastermindScreen(), _FakeMastermind()),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Группа пока не назначена'), findsOneWidget);
      expect(
        find.text('Организатор добавит вас в мастермайнд.'),
        findsOneWidget,
      );
    });
  });

  group('Группа: обычный участник', () {
    testWidgets('видит участников с публичными статусами', (tester) async {
      _tallWindow(tester);
      final c = _FakeMastermind()..group = _group();

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('УЧАСТНИКИ ГРУППЫ'), findsOneWidget);
      expect(find.text('Аслан Демидов — это вы'), findsOneWidget);
      expect(find.text('Адам Глебов'), findsOneWidget);
      expect(find.text('В фокусе'), findsOneWidget);
      expect(find.text('Нужна помощь'), findsOneWidget);
      // Участник без public_status остаётся без чипа
      expect(find.text('Магомед Ильин'), findsOneWidget);
      expect(find.text('Без цели'), findsNothing);
    });

    /// Privacy (раздел 29): чужие строки повестки не показываются участнику,
    /// даже если сервер по ошибке их прислал.
    testWidgets('видит свою строку повестки и сводку, но не чужие детали', (
      tester,
    ) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..group = _group()
        ..nextSession = _session(
          isCurator: false,
          agenda: [
            {
              'user_id': 1,
              'name': 'Аслан Демидов',
              'status': 'behind',
              'needs_help': false,
              'goal_title': 'Выйти на 1,5 млн чистыми',
              'talking_point': 'Расскажите, что мешает движению',
            },
            {
              'user_id': 2,
              'name': 'Адам Глебов',
              'status': 'stuck',
              'needs_help': true,
              'talking_point': 'Чужая проблема — не для общего экрана',
            },
          ],
          summary: {'stuck': 1, 'behind': 1, 'on_track': 3},
        );

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ПОВЕСТКА ВСТРЕЧИ'), findsOneWidget);
      expect(find.text('Расскажите, что мешает движению'), findsOneWidget);

      // Чужая строка отфильтрована на клиенте
      expect(find.text('Чужая проблема — не для общего экрана'), findsNothing);

      // Обезличенная сводка по группе видна
      expect(find.text('Просят помощи'), findsOneWidget);
      expect(find.text('В графике'), findsOneWidget);

      // Пересборка повестки — только у куратора
      expect(find.text('Пересобрать повестку'), findsNothing);
      expect(find.text('Собрать повестку'), findsNothing);
    });
  });

  group('Группа: куратор', () {
    testWidgets('видит полный список повестки и кнопку пересборки', (
      tester,
    ) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..group = _group(isCurator: true)
        ..nextSession = _session(
          isCurator: true,
          agenda: [
            {
              'user_id': 2,
              'name': 'Адам Глебов',
              'status': 'stuck',
              'needs_help': true,
              'talking_point': 'Просит помощи с наймом управляющего',
            },
            {
              'user_id': 1,
              'name': 'Аслан Демидов',
              'status': 'on_track',
              'needs_help': false,
              'progress_percent': 60,
            },
          ],
          summary: {'stuck': 1, 'on_track': 1},
        );

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Требуют разбора: 1 из 2'), findsOneWidget);
      expect(find.text('Адам Глебов'), findsWidgets);
      expect(find.text('Просит помощи с наймом управляющего'), findsOneWidget);
      expect(find.text('Пересобрать повестку'), findsOneWidget);
    });

    testWidgets('пустая повестка предлагает собрать её', (tester) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..group = _group(isCurator: true)
        ..nextSession = _session(isCurator: true);

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Собрать повестку'), findsOneWidget);
    });
  });

  group('Мои обязательства', () {
    testWidgets('показывают срок и просрочку, toggle зовёт контроллер', (
      tester,
    ) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..group = _group()
        ..myCommitments = [
          Commitment.fromJson({
            'id': 11,
            'text': 'Нанять управляющего',
            'due_on': '2026-08-01',
            'is_done': false,
            'is_overdue': true,
            'is_mine': true,
          }),
          Commitment.fromJson({
            'id': 12,
            'text': 'Поднять цены на 12%',
            'is_done': true,
            'is_overdue': false,
            'is_mine': true,
          }),
        ];

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('МОИ ОБЯЗАТЕЛЬСТВА'), findsOneWidget);
      expect(find.textContaining('просрочено'), findsOneWidget);

      await tester.tap(find.text('Нанять управляющего'));
      await tester.pump();

      expect(c.toggledId, 11);
    });
  });

  group('Протокол', () {
    testWidgets('открывается с вкладки группы', (tester) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..group = _group(
          withNext: false,
          lastSession: {
            'id': 4,
            'scheduled_at': '2026-08-10T19:00:00+03:00',
            'notes': 'Разобрали найм',
          },
        )
        ..sessionToReturn = _session(
          isCurator: false,
          status: 'held',
          notes: 'Разобрали найм и цены',
        );

      await tester.pumpWidget(_wrap(const MastermindScreen(), c));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ПРОШЛЫЙ ПРОТОКОЛ'), findsOneWidget);

      await tester.tap(find.text('Протокол встречи'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(c.requestedSessionId, 4);
      expect(find.text('Разобрали найм и цены'), findsOneWidget);
    });

    /// Privacy (раздел 17): участник видит только свои обязательства,
    /// а посещаемость скрыта — даже если сервер её прислал.
    testWidgets('участнику — только свои обязательства и без attendance', (
      tester,
    ) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..sessionToReturn = _session(
          isCurator: false,
          status: 'held',
          notes: 'Итоги встречи',
          commitments: [
            {
              'id': 1,
              'text': 'Моё обязательство',
              'is_done': true,
              'is_mine': true,
            },
            {
              'id': 2,
              'text': 'Чужое обязательство',
              'is_done': false,
              'is_mine': false,
            },
          ],
          attendance: [
            {
              'user_id': 2,
              'name': 'Адам Глебов',
              'status': 'present',
              'status_label': 'Был',
            },
          ],
        );

      await tester.pumpWidget(
        _wrap(const MastermindProtocolScreen(sessionId: 4), c),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Итоги встречи'), findsOneWidget);
      expect(find.text('Моё обязательство'), findsOneWidget);
      expect(find.text('Выполнено'), findsOneWidget);
      expect(find.text('Чужое обязательство'), findsNothing);
      expect(find.text('УЧАСТИЕ'), findsNothing);
    });

    testWidgets('куратору — посещаемость со статусами', (tester) async {
      _tallWindow(tester);
      final c = _FakeMastermind()
        ..sessionToReturn = _session(
          isCurator: true,
          status: 'held',
          attendance: [
            {
              'user_id': 2,
              'name': 'Адам Глебов',
              'status': 'present',
              'status_label': 'Был',
            },
            {
              'user_id': 3,
              'name': 'Магомед Ильин',
              'status': 'absent',
              'status_label': 'Не пришёл',
            },
          ],
        );

      await tester.pumpWidget(
        _wrap(const MastermindProtocolScreen(sessionId: 4), c),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('УЧАСТИЕ'), findsOneWidget);
      expect(find.text('Был'), findsOneWidget);
      expect(find.text('Не пришёл'), findsOneWidget);
    });

    testWidgets('ошибка загрузки предлагает повторить', (tester) async {
      final c = _FakeMastermind(); // sessionToReturn == null → ошибка

      await tester.pumpWidget(
        _wrap(const MastermindProtocolScreen(sessionId: 4), c),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Не удалось загрузить протокол'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });
}
