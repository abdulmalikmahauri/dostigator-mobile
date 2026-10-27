import 'package:dostigator/core/club_time.dart';
import 'package:dostigator/models/habit.dart';
import 'package:dostigator/models/plan.dart';
import 'package:dostigator/models/task.dart';
import 'package:dostigator/screens/habit_form_screen.dart';
import 'package:dostigator/screens/habits_catalog_screen.dart';
import 'package:dostigator/screens/planner_screen.dart';
import 'package:dostigator/screens/task_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/planner.dart';
import 'helpers/planner_stubs.dart';

Future<void> _open(WidgetTester tester, PlannerStubs s, String tab) async {
  await tester.pumpWidget(wrapPlanner(const PlannerScreen(), s));
  await tester.pump();
  if (tab != 'Цели') {
    await tester.tap(find.text(tab));
    await tester.pump();
  }
}

/// Кнопка внизу формы — последней строкой прокрутки.
Future<void> _tapBottom(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  // Данные в тестах — на 11 ноября 2026; «сегодня» — тот же день по Москве
  setUp(() => ClubTime.clock = () => DateTime.utc(2026, 11, 11, 7));
  tearDown(() => ClubTime.clock = DateTime.now);

  group('Планер', () {
    testWidgets('четыре раздела, первым — цели', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();

      await _open(tester, s, 'Цели');

      expect(find.text('Планер'), findsOneWidget);
      for (final tab in ['Цели', 'Привычки', 'Задачи', 'План']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('Поставьте первую цель'), findsOneWidget);
    });
  });

  group('Привычки', () {
    testWidgets('карточка: норма, дни, стабильность', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();
      s.habits.habits = [
        Habit.fromJson(habitJson(percent: 80, planned: 10, done: 8)),
      ];

      await _open(tester, s, 'Привычки');

      expect(find.text('Читать книги'), findsOneWidget);
      expect(find.text('20 страниц · каждый день'), findsOneWidget);
      expect(find.text('Стабильность 80%'), findsOneWidget);
    });

    testWidgets('простая привычка отмечается одним нажатием', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();
      s.habits.habits = [
        Habit.fromJson(habitJson(title: 'Зарядка', unit: null, target: 1)),
      ];

      await _open(tester, s, 'Привычки');
      await tester.tap(find.bySemanticsLabel('Отметить: Зарядка'));
      await tester.pump();

      expect(s.habits.logged.single.$3, 1);
    });

    testWidgets('количество вводится числом', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();
      s.habits.habits = [Habit.fromJson(habitJson())];

      await _open(tester, s, 'Привычки');
      await tester.tap(find.bySemanticsLabel('Отметить: Читать книги'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '12');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(s.habits.logged.single.$3, 12);
    });

    testWidgets('без привычек — приглашение и общие привычки клуба', (
      tester,
    ) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();

      await _open(tester, s, 'Привычки');

      expect(find.text('Новая привычка'), findsOneWidget);
      expect(find.text('Общие привычки клуба'), findsOneWidget);
      expect(find.text('Рейтинг стабильности'), findsOneWidget);
    });

    testWidgets('форма подсказывает похожую общую привычку', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs()
        ..habits.suggestions = [
          ListedHabit.fromJson(listedHabitJson(title: 'Читать книги')),
        ];

      await tester.pumpWidget(wrapPlanner(const HabitFormScreen(), s));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Что делаете'),
        'Чтение книг',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.text('ПОХОЖИЕ УЖЕ ВЕДУТ В КЛУБЕ'), findsOneWidget);
      expect(find.text('Читать книги'), findsOneWidget);
    });

    testWidgets('новая привычка: дни и видимость уходят как выбраны', (
      tester,
    ) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();

      await tester.pumpWidget(wrapPlanner(const HabitFormScreen(), s));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Что делаете'),
        'Бег',
      );
      // Подсказка похожих ищется с задержкой — дожидаемся её
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Единица'),
        'км',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Норма'), '3');
      await tester.tap(find.text('По будням'));
      await tester.tap(find.text('Видна всему клубу'));
      await tester.pump();
      await _tapBottom(tester, 'Сохранить привычку');

      final draft = s.habits.created.single;
      expect(draft.title, 'Бег');
      expect(draft.unit, 'км');
      expect(draft.target, 3);
      expect(draft.days, [1, 2, 3, 4, 5]);
      expect(draft.isPublic, isTrue);
    });

    testWidgets('в каталоге присоединяются со своей нормой', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs()
        ..habits.catalogResult = [ListedHabit.fromJson(listedHabitJson(id: 3))];

      await tester.pumpWidget(wrapPlanner(const HabitsCatalogScreen(), s));
      await tester.pump();
      await tester.tap(find.text('Присоединиться'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '5');
      await tester.tap(find.widgetWithText(FilledButton, 'Присоединиться'));
      await tester.pumpAndSettle();

      expect(s.habits.joined.single, (3, 5));
    });
  });

  group('Задачи', () {
    testWidgets('в работе: срок, кто видит и отметка', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();
      s.tasks.open = [
        Task.fromJson(taskJson(visibility: 'internal', dueOn: '2026-11-12')),
      ];

      await _open(tester, s, 'Задачи');

      expect(find.text('Позвонить поставщику'), findsOneWidget);
      expect(find.textContaining('12 ноября'), findsOneWidget);
      expect(find.textContaining('Видят организаторы'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Сделано: Позвонить поставщику'));
      await tester.pump();

      expect(s.tasks.toggled, [1]);
    });

    testWidgets('форма: три вида видимости с пояснением', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();

      await tester.pumpWidget(wrapPlanner(const TaskFormScreen(), s));
      for (final v in TaskVisibility.values) {
        expect(find.text(v.label), findsOneWidget);
        expect(find.text(v.hint), findsOneWidget);
      }

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Задача'),
        'Сдать отчёт куратору',
      );
      await tester.tap(find.text('Видят организаторы'));
      await tester.pump();
      await _tapBottom(tester, 'Сохранить задачу');

      expect(s.tasks.created.single.visibility, TaskVisibility.internal);
      expect(s.tasks.created.single.title, 'Сдать отчёт куратору');
    });

    testWidgets('без названия задача не сохраняется', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();

      await tester.pumpWidget(wrapPlanner(const TaskFormScreen(), s));
      await _tapBottom(tester, 'Сохранить задачу');

      expect(find.text('Напишите, что сделать'), findsOneWidget);
      expect(s.tasks.created, isEmpty);
    });
  });

  group('План', () {
    testWidgets('статистика, просроченное и дни', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();
      final plan = PlanResponse.fromJson(
        planJson()['data'] as Map<String, dynamic>,
      );
      s.plan
        ..days = plan.days
        ..overdue = plan.overdue
        ..stats = PlannerStats.fromJson(
          statsJson()['data'] as Map<String, dynamic>,
        )
        ..loaded = true;

      await _open(tester, s, 'План');

      expect(find.text('дня подряд'), findsOneWidget);
      expect(find.text('ПРОСРОЧЕНО'), findsOneWidget);
      expect(find.text('Сдать отчёт'), findsOneWidget);
      expect(find.text('Бизнес-завтрак'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('0 из 20 страниц'), findsOneWidget);
    });

    testWidgets('у простой привычки в плане нет «0 из 1»', (tester) async {
      tallPlannerWindow(tester);
      final s = PlannerStubs();
      s.plan
        ..days = [
          PlanDay.fromJson({
            'date': '2026-11-11',
            'items': [
              {
                'kind': 'habit',
                'id': 1,
                'title': 'Зарядка',
                'date': '2026-11-11',
                'done': false,
                'value': 0,
                'target': 1,
                'unit': null,
              },
            ],
          }),
        ]
        ..loaded = true;

      await _open(tester, s, 'План');

      expect(find.text('Зарядка'), findsOneWidget);
      expect(find.textContaining('из 1'), findsNothing);
    });
  });
}
