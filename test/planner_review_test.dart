import 'package:dostigator/core/club_time.dart';
import 'package:dostigator/models/habit.dart';
import 'package:dostigator/screens/habits_catalog_screen.dart';
import 'package:dostigator/screens/planner_screen.dart';
import 'package:dostigator/state/habits_controller.dart';
import 'package:dostigator/state/plan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api.dart';
import 'helpers/manual_adapter.dart';
import 'helpers/planner.dart';
import 'helpers/planner_stubs.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  tearDown(() => ClubTime.clock = DateTime.now);

  /// Окно жалобы открывается из меню и не закрывается само.
  testWidgets('жалоба из каталога открывает окно и не закрывает его', (
    tester,
  ) async {
    tallPlannerWindow(tester);
    final s = PlannerStubs()
      ..habits.catalogResult = [ListedHabit.fromJson(listedHabitJson())];

    await tester.pumpWidget(wrapPlanner(const HabitsCatalogScreen(), s));
    await tester.pump();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пожаловаться'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Отправить'), findsOneWidget);
  });

  /// Вчерашняя «сегодня» после полуночи: отметка не должна уйти во вчера.
  testWidgets('после полуночи привычки сначала обновляются', (tester) async {
    tallPlannerWindow(tester);
    ClubTime.clock = () => DateTime.utc(2026, 11, 11, 7);
    final s = PlannerStubs();
    // Загружено вчера: «сегодня» в данных — 10 ноября
    final stale = habitJson(title: 'Зарядка', unit: null, target: 1);
    (stale['today'] as Map<String, dynamic>)['date'] = '2026-11-10';
    s.habits.habits = [Habit.fromJson(stale)];

    // В приложении экран живёт внутри каркаса с нижним меню
    await tester.pumpWidget(
      wrapPlanner(const Scaffold(body: PlannerScreen()), s),
    );
    await tester.pump();
    await tester.tap(find.text('Привычки'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Отметить: Зарядка'));
    await tester.pump();

    expect(s.habits.logged, isEmpty);
    expect(s.habits.loads, greaterThan(0));
  });

  group('Контроллеры', () {
    test('сбой одной отметки не откатывает другую', () async {
      final (:api, :adapter) = manualApi();
      final c = HabitsController(api)
        ..habits = [
          Habit.fromJson(habitJson(id: 1, title: 'А', unit: null, target: 1)),
          Habit.fromJson(habitJson(id: 2, title: 'Б', unit: null, target: 1)),
        ];
      final today = c.habits.first.today.date;

      final first = c.log(1, today, 1);
      final second = c.log(2, today, 1);
      await adapter.waitFor(2);

      adapter.reply((o) => o.path == '/habits/2/log', {
        'data': habitJson(
          id: 2,
          title: 'Б',
          unit: null,
          target: 1,
          todayValue: 1,
          todayDone: true,
        ),
      });
      await second;
      adapter.reply((o) => o.path == '/habits/1/log', {
        'message': 'Отметить можно только за последнюю неделю',
      }, status: 422);
      await first;

      expect(c.habits.firstWhere((h) => h.id == 1).today.done, isFalse);
      expect(c.habits.firstWhere((h) => h.id == 2).today.done, isTrue);
    });

    test('ответ после выхода из аккаунта не роняет приложение', () async {
      final (:api, :adapter) = manualApi();
      final c = HabitsController(api);

      final pending = c.load();
      await adapter.waitFor(1);
      c.dispose();
      adapter.reply((o) => o.path == '/habits', {'data': []});

      await expectLater(pending, completes);
    });

    test('«ещё неделя» не удалась — показываем столько же дней', () async {
      var calls = 0;
      final (:api, :stub) = stubbedApi((call) {
        if (call.path == '/planner/stats') return (200, statsJson());
        calls++;
        return calls == 1
            ? (200, planJson())
            : (422, {'message': 'За раз — не больше двух месяцев'});
      });
      final c = PlanController(api, today: () => DateTime.utc(2026, 11, 11));
      await c.load();

      await c.showMore();
      await c.load(silent: true);

      final last = stub.calls.lastWhere((x) => x.path == '/planner');
      expect(last.query['to'], '2026-11-17');
    });
  });
}
