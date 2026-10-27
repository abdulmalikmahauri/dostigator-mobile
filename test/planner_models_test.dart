import 'package:dostigator/models/habit.dart';
import 'package:dostigator/models/plan.dart';
import 'package:dostigator/models/task.dart';
import 'package:dostigator/state/habits_controller.dart';
import 'package:dostigator/state/plan_controller.dart';
import 'package:dostigator/state/tasks_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/api.dart';
import 'helpers/planner.dart';

void main() {
  group('Привычка', () {
    test('разбирается вместе с неделей и стабильностью', () {
      final h = Habit.fromJson(habitJson(percent: 80, planned: 10, done: 8));

      expect(h.title, 'Читать книги');
      expect(h.norm, '20 страниц');
      expect(h.daysLabel, 'каждый день');
      expect(h.week, hasLength(7));
      expect(h.stability.percent, 80);
      expect(h.stability.inRating, isTrue);
      expect(h.isCheck, isFalse);
    });

    test('дни недели — коротко и по-человечески', () {
      expect(HabitDays.label([1, 2, 3, 4, 5]), 'по будням');
      expect(HabitDays.label([6, 7]), 'по выходным');
      expect(HabitDays.label([1, 3, 5]), 'пн, ср, пт');
    });

    test('«сделал / не сделал» без единицы — простая отметка', () {
      final h = Habit.fromJson(habitJson(unit: null, target: 1));

      expect(h.isCheck, isTrue);
      expect(h.norm, 'Отметка');
    });
  });

  group('Задача', () {
    test('разбирается с видом и сроком', () {
      final t = Task.fromJson(
        taskJson(visibility: 'internal', dueOn: '2026-11-12'),
      );

      expect(t.visibility, TaskVisibility.internal);
      expect(t.dueOn, DateTime.utc(2026, 11, 12));
      expect(t.isDone, isFalse);
    });

    test('черновик уходит с датой без времени, пустые поля — пустыми', () {
      final draft = TaskDraft(
        title: '  Позвонить поставщику ',
        notes: '',
        dueOn: DateTime.utc(2026, 11, 12),
        visibility: TaskVisibility.public,
      );

      expect(draft.toJson(), {
        'title': 'Позвонить поставщику',
        'notes': null,
        'due_on': '2026-11-12',
        'visibility': 'public',
      });
    });
  });

  group('Контроллер привычек', () {
    test('отметка видна сразу, до ответа сервера', () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.method == 'GET') {
          return (
            200,
            {
              'data': [habitJson()],
            },
          );
        }
        return (200, {'data': habitJson(todayValue: 20, todayDone: true)});
      });
      final c = HabitsController(api);
      await c.load();

      final pending = c.log(c.habits.single.id, DateTime.utc(2026, 11, 11), 20);
      expect(c.habits.single.today.done, isTrue);

      expect(await pending, isNull);
      expect(stub.calls.last.body, {'date': '2026-11-11', 'value': 20});
    });

    test('сервер отказал — отметка возвращается как была', () async {
      final (:api, stub: _) = stubbedApi((call) {
        if (call.method == 'GET') {
          return (
            200,
            {
              'data': [habitJson()],
            },
          );
        }
        return (
          422,
          {
            'message': 'Отметить можно только за последнюю неделю',
            'errors': {
              'date': ['Отметить можно только за последнюю неделю'],
            },
          },
        );
      });
      final c = HabitsController(api);
      await c.load();

      final error = await c.log(1, DateTime.utc(2026, 11, 11), 20);

      expect(error, 'Отметить можно только за последнюю неделю');
      expect(c.habits.single.today.done, isFalse);
    });

    test('присоединение добавляет привычку в мои', () async {
      final (:api, :stub) = stubbedApi(
        (call) => (201, {'data': habitJson(id: 7, target: 10)}),
      );
      final c = HabitsController(api);

      await c.join(7, 10);

      expect(c.habits.single.target, 10);
      expect(stub.calls.single.path, '/habits/7/join');
    });
  });

  group('Контроллер задач', () {
    test('отметка «сделано» переносит задачу и видна сразу', () async {
      final (:api, stub: _) = stubbedApi((call) {
        if (call.method == 'GET') {
          return (
            200,
            {
              'data': [taskJson()],
            },
          );
        }
        return (200, {'data': taskJson(isDone: true)});
      });
      final c = TasksController(api);
      await c.load();

      final pending = c.toggle(c.open.single.id);
      expect(c.open, isEmpty);

      expect(await pending, isNull);
      expect(c.done.single.isDone, isTrue);
    });

    test('новая задача встаёт в список', () async {
      final (:api, :stub) = stubbedApi(
        (call) => (201, {'data': taskJson(id: 5, title: 'Купить подарок')}),
      );
      final c = TasksController(api);

      await c.create(const TaskDraft(title: 'Купить подарок'));

      expect(c.open.single.title, 'Купить подарок');
      expect(stub.calls.single.body?['visibility'], 'private');
    });
  });

  group('План', () {
    test('неделя с сегодняшнего дня и статистика', () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.path == '/planner/stats') return (200, statsJson());
        return (200, planJson());
      });
      final c = PlanController(api, today: () => DateTime.utc(2026, 11, 11));

      await c.load();

      expect(c.days.first.date, DateTime.utc(2026, 11, 11));
      expect(c.days.first.items.single.kind, PlanKind.habit);
      expect(c.overdue.single.title, 'Сдать отчёт');
      expect(c.stats?.totals.streak, 3);
      final planCall = stub.calls.firstWhere((x) => x.path == '/planner');
      expect(planCall.query, {'from': '2026-11-11', 'to': '2026-11-17'});
    });
  });
}
