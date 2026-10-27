import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/event.dart';
import 'package:dostigator/models/goal.dart';
import 'package:dostigator/models/mastermind.dart';
import 'package:dostigator/models/resident.dart';
import 'package:dostigator/screens/pulse_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/events_controller.dart';
import 'package:dostigator/state/goals_controller.dart';
import 'package:dostigator/state/mastermind_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/directory.dart';
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

ApiClient _api() {
  // Сети в тестах нет; адрес заведомо мёртвый, чтобы случайный
  // непереопределённый запрос упал быстро и предсказуемо.
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Фейковые контроллеры: initState Пульса зовёт load()/refreshResident(),
/// а тесты кормят данные напрямую — сетевые методы глушим, чтобы
/// подготовленное состояние не затиралось ошибкой сети.
class _StillGoals extends GoalsController {
  _StillGoals(super.api);

  @override
  Future<void> load({bool silent = false}) async {}
}

class _StillMastermind extends MastermindController {
  _StillMastermind(super.api);

  @override
  Future<void> load({bool silent = false}) async {}
}

class _StillEvents extends EventsController {
  _StillEvents(super.api);

  @override
  Future<void> load({bool silent = false}) async {}
}

class _StillAuth extends AuthController {
  _StillAuth({required super.api, required super.tokens});

  @override
  Future<void> refreshResident() async {}
}

Goal _goal({
  int id = 1,
  String title = 'Выйти на 1,5 млн чистыми',
  bool isMain = false,
  bool checkedIn = false,
  int progress = 50,
  bool hideValues = false,
  int missedWeeks = 0,
}) {
  return Goal.fromJson({
    'id': id,
    'title': title,
    'is_main': isMain,
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
    'checked_in_this_week': checkedIn,
    'missed_weeks': missedWeeks,
    'steps': [],
    'checkins': [],
  });
}

Resident _resident({bool overdue = false}) {
  return Resident.fromJson({
    'id': 1,
    'name': 'Али-Бек Мусаев',
    'phone': '+79000000001',
    'card_number': 'DG-00001',
    'tier_label': 'Бизнес-клуб',
    'is_club_member': true,
    'memberships': [
      {
        'tier': 'club',
        'tier_label': 'Бизнес-клуб',
        'status_label': overdue ? 'Просрочен' : 'Действует',
        'is_overdue': overdue,
      },
    ],
  });
}

MastermindGroup _group() {
  return MastermindGroup.fromJson({
    'id': 1,
    'name': 'Группа Альфа',
    'is_curator': false,
    'members': const [],
    // Время без смещения: разбирается как локальное, и «19:00»
    // не зависит от часового пояса машины, где идут тесты
    'next_session': {
      'id': 5,
      'scheduled_at': '2026-09-20T19:00:00',
      'has_agenda': false,
    },
  });
}

Commitment _commitment(
  int id,
  String text, {
  bool done = false,
  bool overdue = false,
}) {
  return Commitment.fromJson({
    'id': id,
    'text': text,
    'is_done': done,
    'is_overdue': overdue,
    'is_mine': true,
  });
}

ClubEvent _event() {
  return ClubEvent.fromJson({
    'id': 1,
    'title': 'Бизнес-завтрак',
    'type_label': 'Бизнес-завтрак',
    'starts_at': '2026-09-25T09:00:00',
    'place': 'Офис экосистемы',
    'price': 0,
    'is_free': true,
    'is_past': false,
    'is_full': false,
    'is_available': true,
    'is_registered': false,
    'checked_in': false,
  });
}

class _Harness {
  _Harness({
    List<Goal> goals = const [],
    MastermindGroup? group,
    List<Commitment> commitments = const [],
    List<ClubEvent> events = const [],
    Resident? resident,
    void Function(int index)? onOpenTab,
  }) {
    final api = _api();
    this.goals = _StillGoals(api)..goals = goals;
    mastermind = _StillMastermind(api)
      ..group = group
      ..myCommitments = commitments;
    this.events = _StillEvents(api)..upcoming = events;
    auth = _StillAuth(api: api, tokens: _FakeStorage())
      ..resident = resident ?? _resident();
    screen = PulseScreen(onOpenTab: onOpenTab ?? (_) {});
  }

  late final GoalsController goals;
  late final MastermindController mastermind;
  late final EventsController events;
  late final AuthController auth;
  late final PulseScreen screen;

  Widget build() {
    return MultiProvider(
      providers: [
        themeProvider(),
        directoryProvider(),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<GoalsController>.value(value: goals),
        ChangeNotifierProvider<MastermindController>.value(value: mastermind),
        ChangeNotifierProvider<EventsController>.value(value: events),
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
        home: screen,
      ),
    );
  }
}

/// Экран длиннее тестового окна, а ListView строит только видимое —
/// без высокого окна нижние блоки просто не дойдут до отрисовки.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, _Harness h) async {
  await tester.pumpWidget(h.build());
  // Даём кольцу прогресса доиграть анимацию появления (700 мс)
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  testWidgets('с целью показываются фокус недели, кольцо и KPI', (
    tester,
  ) async {
    _tallWindow(tester);
    final h = _Harness(goals: [_goal()]);

    await _pump(tester, h);

    expect(find.text('ФОКУС НЕДЕЛИ'), findsOneWidget);
    expect(find.text('Выйти на 1,5 млн чистыми'), findsOneWidget);
    expect(find.text('РЕЗУЛЬТАТ'), findsOneWidget);
    expect(find.text('ЦЕЛЬ'), findsOneWidget);
    expect(find.text('1 200 000 ₽'), findsOneWidget);
    expect(find.text('1 500 000 ₽'), findsOneWidget);
    // Процент есть и в кольце, и в KPI «ПРОГРЕСС»
    expect(find.text('50%'), findsWidgets);
    expect(find.text('90 дней'), findsOneWidget);
  });

  testWidgets('без цели — пустое состояние с призывом её поставить', (
    tester,
  ) async {
    _tallWindow(tester);
    final h = _Harness(goals: const []);

    await _pump(tester, h);

    expect(find.text('Поставьте первую цель'), findsOneWidget);
    expect(find.text('Поставить цель'), findsOneWidget);
    // Без цели отчитываться не о чем — блока check-in нет
    expect(find.text('CHECK-IN НЕДЕЛИ'), findsNothing);
  });

  testWidgets('несданный check-in зовёт заполнить отчёт', (tester) async {
    _tallWindow(tester);
    final h = _Harness(goals: [_goal(checkedIn: false)]);

    await _pump(tester, h);

    expect(find.text('CHECK-IN НЕДЕЛИ'), findsOneWidget);
    expect(find.text('Подведите итоги недели'), findsOneWidget);
    expect(find.text('Следующий отчёт: до воскресенья'), findsOneWidget);
    expect(find.text('Заполнить'), findsOneWidget);
  });

  testWidgets('сданный check-in — статус без кнопки', (tester) async {
    _tallWindow(tester);
    final h = _Harness(goals: [_goal(checkedIn: true)]);

    await _pump(tester, h);

    expect(find.text('Отчёт за эту неделю отправлен'), findsOneWidget);
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Заполнить'), findsNothing);
  });

  /// Резидент попросил скрыть суммы — интерфейс обязан это уважать,
  /// иначе настройка приватности бессмысленна.
  testWidgets('приватная цель показывает только процент и срок', (
    tester,
  ) async {
    _tallWindow(tester);
    final h = _Harness(goals: [_goal(hideValues: true)]);

    await _pump(tester, h);

    expect(find.text('РЕЗУЛЬТАТ'), findsNothing);
    expect(find.text('ЦЕЛЬ'), findsNothing);
    expect(find.text('1 200 000 ₽'), findsNothing);
    expect(find.text('ПРОГРЕСС'), findsOneWidget);
    expect(find.text('50%'), findsWidgets);
    expect(
      find.text('Абсолютные значения скрыты настройкой приватности'),
      findsOneWidget,
    );
  });

  testWidgets(
    'мастермайнд, обязательства и событие выводятся из контроллеров',
    (tester) async {
      _tallWindow(tester);
      final h = _Harness(
        goals: [_goal(checkedIn: true)],
        group: _group(),
        commitments: [
          _commitment(1, 'Подготовить финмодель', done: true),
          _commitment(2, 'Собрать отдел продаж', overdue: true),
          _commitment(3, 'Провести кастдев'),
          _commitment(4, 'Лишнее четвёртое'),
        ],
        events: [_event()],
      );

      await _pump(tester, h);

      expect(find.text('БЛИЖАЙШИЙ МАСТЕРМАЙНД'), findsOneWidget);
      expect(find.text('Группа Альфа'), findsOneWidget);
      expect(find.text('20 сентября 2026 · 19:00'), findsOneWidget);

      expect(find.text('МОИ ОБЯЗАТЕЛЬСТВА'), findsOneWidget);
      expect(find.text('Подготовить финмодель'), findsOneWidget);
      expect(find.text('Просрочено'), findsOneWidget);
      expect(find.text('Открыто'), findsOneWidget);
      // Показываем максимум три — четвёртое остаётся на вкладке «Группа»
      expect(find.text('Лишнее четвёртое'), findsNothing);

      expect(find.text('БЛИЖАЙШЕЕ СОБЫТИЕ'), findsOneWidget);
      expect(find.text('Бизнес-завтрак'), findsOneWidget);
      expect(find.textContaining('Офис экосистемы'), findsOneWidget);
    },
  );

  testWidgets('без группы блок мастермайнда скрыт', (tester) async {
    _tallWindow(tester);
    final h = _Harness(goals: [_goal(checkedIn: true)]);

    await _pump(tester, h);

    expect(find.text('БЛИЖАЙШИЙ МАСТЕРМАЙНД'), findsNothing);
    expect(find.text('МОИ ОБЯЗАТЕЛЬСТВА'), findsNothing);
  });

  /// Целей несколько — на главном экране главная, остальные одной строкой.
  testWidgets('показывает главную цель и число остальных', (tester) async {
    _tallWindow(tester);
    final h = _Harness(
      goals: [
        // Все отчёты сданы: карточка check-in названий целей не повторяет
        _goal(
          id: 1,
          title: 'Открыть третью кофейню',
          isMain: true,
          checkedIn: true,
        ),
        _goal(id: 2, title: 'Пробежать полумарафон', checkedIn: true),
        _goal(id: 3, title: 'Выучить английский', checkedIn: true),
      ],
    );

    await _pump(tester, h);

    expect(find.text('Открыть третью кофейню'), findsOneWidget);
    expect(find.text('Главная цель · ещё 2 в работе'), findsOneWidget);
    expect(find.text('Пробежать полумарафон'), findsNothing);
  });

  /// Главная цель уже отмечена, вторая — нет: зовём отчитаться по второй.
  testWidgets('check-in зовёт к цели, по которой отчёта ещё нет', (
    tester,
  ) async {
    _tallWindow(tester);
    final h = _Harness(
      goals: [
        _goal(
          id: 1,
          title: 'Открыть третью кофейню',
          isMain: true,
          checkedIn: true,
        ),
        _goal(id: 2, title: 'Пробежать полумарафон'),
      ],
    );

    await _pump(tester, h);

    expect(find.text('Заполнить'), findsOneWidget);
    expect(find.text('Пробежать полумарафон'), findsOneWidget);
  });

  /// Просили поднять наверх: внизу экрана про долг никто не узнавал.
  testWidgets('предупреждение о взносе стоит первым блоком', (tester) async {
    _tallWindow(tester);
    final h = _Harness(
      goals: [_goal(checkedIn: true)],
      resident: _resident(overdue: true),
    );

    await _pump(tester, h);

    final warning = tester.getTopLeft(find.text('Взнос не оплачен')).dy;
    final goal = tester.getTopLeft(find.text('ФОКУС НЕДЕЛИ')).dy;

    expect(warning, lessThan(goal));
  });

  testWidgets('долг по взносу вытесняет карточку доступа', (tester) async {
    _tallWindow(tester);
    final h = _Harness(
      goals: [_goal(checkedIn: true)],
      resident: _resident(overdue: true),
    );

    await _pump(tester, h);

    expect(find.text('Взнос не оплачен'), findsOneWidget);
    expect(find.text('Покажите QR на стойке'), findsNothing);
  });

  testWidgets('без долга виден доступ в клуб', (tester) async {
    _tallWindow(tester);
    final h = _Harness(goals: [_goal(checkedIn: true)]);

    await _pump(tester, h);

    expect(find.text('ДОСТУП В КЛУБ'), findsOneWidget);
    expect(find.text('Покажите QR на стойке'), findsOneWidget);
    expect(find.text('Взнос не оплачен'), findsNothing);
  });

  testWidgets('tap по карточке цели открывает вкладку «Цели»', (tester) async {
    _tallWindow(tester);
    int? opened;
    final h = _Harness(goals: [_goal()], onOpenTab: (i) => opened = i);

    await _pump(tester, h);

    await tester.tap(find.text('ФОКУС НЕДЕЛИ'));
    await tester.pump();

    expect(opened, 1);
  });
}
