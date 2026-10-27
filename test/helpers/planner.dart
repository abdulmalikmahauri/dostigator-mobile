/// Ответы сервера для привычек, задач и плана — как их отдаёт бэкенд.
library;

Map<String, dynamic> habitJson({
  int id = 1,
  String title = 'Читать книги',
  String? unit = 'страниц',
  int target = 20,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  bool isPublic = false,
  bool isOwner = true,
  int participants = 1,
  int todayValue = 0,
  bool todayDone = false,
  int? percent,
  int planned = 0,
  int done = 0,
}) {
  return {
    'id': id,
    'title': title,
    'unit': unit,
    'target': target,
    'days': days,
    'is_public': isPublic,
    'is_listed': isPublic,
    'is_owner': isOwner,
    'participants_count': participants,
    'today': {
      'date': '2026-11-11',
      'planned': true,
      'value': todayValue,
      'done': todayDone,
    },
    'week': [
      for (var d = 5; d <= 11; d++)
        {
          'date': '2026-11-${d.toString().padLeft(2, '0')}',
          'planned': true,
          'value': d.isEven ? target : 0,
          'done': d.isEven,
        },
    ],
    'stability': {
      'percent': percent,
      'planned': planned,
      'done': done,
      'in_rating': planned >= 7,
    },
  };
}

Map<String, dynamic> listedHabitJson({
  int id = 3,
  String title = 'Бег по утрам',
  String? unit = 'км',
  int target = 3,
  bool isJoined = false,
  int participants = 4,
}) {
  return {
    'id': id,
    'title': title,
    'unit': unit,
    'target': target,
    'days': [1, 2, 3, 4, 5, 6, 7],
    'owner_name': 'Аслан',
    'participants_count': participants,
    'is_joined': isJoined,
    'is_owner': false,
  };
}

Map<String, dynamic> taskJson({
  int id = 1,
  String title = 'Позвонить поставщику',
  String visibility = 'private',
  String? dueOn,
  bool isDone = false,
  bool isOverdue = false,
}) {
  return {
    'id': id,
    'title': title,
    'notes': null,
    'due_on': dueOn,
    'visibility': visibility,
    'visibility_label': switch (visibility) {
      'public' => 'Видят все',
      'internal' => 'Видят организаторы',
      _ => 'Только я',
    },
    'is_done': isDone,
    'done_at': isDone ? '2026-11-11T10:00:00+00:00' : null,
    'is_overdue': isOverdue,
    'is_hidden': false,
  };
}

Map<String, dynamic> planJson() {
  return {
    'data': {
      'days': [
        {
          'date': '2026-11-11',
          'items': [
            {
              'kind': 'habit',
              'id': 1,
              'title': 'Читать книги',
              'subtitle': null,
              'date': '2026-11-11',
              'time': null,
              'done': false,
              'value': 0,
              'target': 20,
              'unit': 'страниц',
            },
          ],
        },
        {
          'date': '2026-11-12',
          'items': [
            {
              'kind': 'event',
              'id': 9,
              'title': 'Бизнес-завтрак',
              'subtitle': 'Офис экосистемы',
              'date': '2026-11-12',
              'time': '09:00',
              'done': null,
            },
            {
              'kind': 'task',
              'id': 4,
              'title': 'Позвонить поставщику',
              'subtitle': null,
              'date': '2026-11-12',
              'time': null,
              'done': false,
              'visibility': 'private',
            },
          ],
        },
      ],
      'overdue': [
        taskJson(
          id: 2,
          title: 'Сдать отчёт',
          dueOn: '2026-11-09',
          isOverdue: true,
        ),
      ],
    },
  };
}

Map<String, dynamic> statsJson() {
  return {
    'data': {
      'days': [
        for (var d = 29; d <= 31; d++)
          {
            'date': '2026-10-$d',
            'habits_planned': 2,
            'habits_done': 1,
            'tasks_done': 0,
          },
        for (var d = 1; d <= 11; d++)
          {
            'date': '2026-11-${d.toString().padLeft(2, '0')}',
            'habits_planned': 2,
            'habits_done': d > 8 ? 2 : 1,
            'tasks_done': d == 10 ? 2 : 0,
          },
      ],
      'totals': {'habits_percent': 64, 'tasks_done': 2, 'streak': 3},
    },
  };
}
