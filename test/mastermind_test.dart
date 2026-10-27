import 'package:dostigator/models/mastermind.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item({
  required int id,
  required String name,
  required String status,
  int? progress,
  String? talkingPoint,
  bool needsHelp = false,
}) {
  return {
    'user_id': id,
    'name': name,
    'status': status,
    'needs_help': needsHelp,
    'goal_title': 'Цель $name',
    'progress_percent': progress,
    'talking_point': talkingPoint,
  };
}

void main() {
  group('Повестка мастермайнда', () {
    test('статус разбирается и неизвестный не роняет приложение', () {
      expect(AgendaStatus.parse('stuck'), AgendaStatus.stuck);
      expect(AgendaStatus.parse('silent'), AgendaStatus.silent);
      expect(AgendaStatus.parse('no_goal'), AgendaStatus.noGoal);

      // Сервер может добавить новый статус раньше, чем обновится приложение
      expect(AgendaStatus.parse('нечто_новое'), AgendaStatus.onTrack);
      expect(AgendaStatus.parse(null), AgendaStatus.onTrack);
    });

    test('требующие разбора отделены от благополучных', () {
      expect(AgendaStatus.stuck.needsDiscussion, isTrue);
      expect(AgendaStatus.silent.needsDiscussion, isTrue);
      expect(AgendaStatus.behind.needsDiscussion, isTrue);
      expect(AgendaStatus.noGoal.needsDiscussion, isTrue);

      expect(AgendaStatus.onTrack.needsDiscussion, isFalse);
      expect(AgendaStatus.achieved.needsDiscussion, isFalse);
    });

    test('сессия считает, скольких надо разобрать', () {
      final session = MastermindSession.fromJson({
        'id': 1,
        'scheduled_at': '2026-09-20T19:00:00+03:00',
        'status': 'agenda_ready',
        'is_curator': true,
        'agenda': [
          _item(id: 1, name: 'Застрял', status: 'stuck', needsHelp: true),
          _item(id: 2, name: 'Молчит', status: 'silent'),
          _item(id: 3, name: 'В графике', status: 'on_track', progress: 60),
        ],
        'agenda_summary': {
          'stuck': 1,
          'silent': 1,
          'behind': 0,
          'on_track': 1,
          'achieved': 0,
          'no_goal': 0,
        },
        'commitments': [],
      });

      expect(session.agenda, hasLength(3));
      expect(session.needAttention, 2);
      expect(session.isCurator, isTrue);
      expect(session.agenda.first.needsHelp, isTrue);
    });

    /// Обычный участник получает с сервера только свою строку.
    /// Приложение не должно этому удивляться.
    test('повестка из одной строки разбирается штатно', () {
      final session = MastermindSession.fromJson({
        'id': 2,
        'scheduled_at': '2026-09-20T19:00:00+03:00',
        'status': 'agenda_ready',
        'is_curator': false,
        'agenda': [_item(id: 7, name: 'Я', status: 'behind', progress: 20)],
        'agenda_summary': {'stuck': 1, 'behind': 1, 'on_track': 3},
        'commitments': [],
      });

      expect(session.isCurator, isFalse);
      expect(session.agenda, hasLength(1));
      // Сводка по группе видна даже без имён
      expect(session.needAttention, 2);
    });

    test('пустая повестка не роняет разбор', () {
      final session = MastermindSession.fromJson({
        'id': 3,
        'scheduled_at': '2026-09-20T19:00:00+03:00',
        'status': 'planned',
        'is_curator': true,
      });

      expect(session.agenda, isEmpty);
      expect(session.needAttention, 0);
      expect(session.commitments, isEmpty);
    });
  });

  group('Группа', () {
    test('разбирается с куратором, составом и ближайшей встречей', () {
      final group = MastermindGroup.fromJson({
        'id': 1,
        'name': 'Группа Альфа',
        'is_curator': false,
        'place': 'Офис в центре',
        'curator': {'id': 9, 'name': 'Али-Бек Мусаев'},
        'members': [
          {
            'id': 1,
            'name': 'Аслан Демидов',
            'business': 'Склад-Сервис',
            'is_me': true,
          },
          {'id': 2, 'name': 'Адам Глебов', 'is_me': false},
        ],
        'members_count': 2,
        'next_session': {
          'id': 5,
          'scheduled_at': '2026-09-20T19:00:00+03:00',
          'place': 'Офис в центре',
          'status': 'agenda_ready',
          'has_agenda': true,
        },
        'last_session': {'id': 4, 'notes': 'Разобрали найм'},
      });

      expect(group.name, 'Группа Альфа');
      expect(group.curatorName, 'Али-Бек Мусаев');
      expect(group.members, hasLength(2));
      expect(group.members.first.isMe, isTrue);
      expect(group.nextSession?.hasAgenda, isTrue);
      expect(group.lastSessionNotes, 'Разобрали найм');
    });

    test('группа без встреч и куратора разбирается', () {
      final group = MastermindGroup.fromJson({
        'id': 2,
        'name': 'Новая группа',
        'is_curator': true,
        'members': [],
      });

      expect(group.curatorName, isNull);
      expect(group.nextSession, isNull);
      expect(group.members, isEmpty);
      expect(group.isCurator, isTrue);
    });
  });

  group('Обязательства', () {
    test('просроченное помечено', () {
      final c = Commitment.fromJson({
        'id': 1,
        'text': 'Нанять управляющего',
        'due_on': '2026-08-01',
        'is_done': false,
        'is_overdue': true,
        'is_mine': true,
      });

      expect(c.isOverdue, isTrue);
      expect(c.isDone, isFalse);
      expect(c.dueOn?.month, 8);
    });

    test('обязательство без срока разбирается', () {
      final c = Commitment.fromJson({
        'id': 2,
        'text': 'Без срока',
        'is_done': true,
      });

      expect(c.dueOn, isNull);
      expect(c.isDone, isTrue);
    });
  });
}
