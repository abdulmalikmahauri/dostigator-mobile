import 'package:dostigator/models/event.dart';
import 'package:dostigator/models/event_filter.dart';
import 'package:dostigator/models/event_proposal.dart';
import 'package:dostigator/models/meeting.dart';
import 'package:dostigator/state/events_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/api.dart';

Map<String, dynamic> _event({
  int id = 1,
  String title = 'Бизнес-завтрак',
  String startsAt = '2026-11-12T09:00:00+00:00',
  String format = 'offline',
  String formatLabel = 'Очно',
  String? topic,
  bool isRegistered = false,
  bool isPast = false,
  bool checkedIn = false,
  int photosCount = 0,
}) => {
  'id': id,
  'title': title,
  'type': 'breakfast',
  'type_label': 'Бизнес-завтрак',
  'format': format,
  'format_label': formatLabel,
  'topic': topic,
  'starts_at': startsAt,
  'is_past': isPast,
  'is_registered': isRegistered,
  'checked_in': checkedIn,
  'photos_count': photosCount,
};

Map<String, dynamic> _meeting({
  int id = 1,
  String title = 'Заседание клуба',
  String scheduledAt = '2026-11-12T19:00:00+00:00',
  String myStatus = 'expected',
  String myStatusLabel = 'Ожидается',
  bool isPast = false,
}) => {
  'id': id,
  'title': title,
  'scheduled_at': scheduledAt,
  'place': 'Офис экосистемы',
  'audience': 'club',
  'audience_label': 'Весь бизнес-клуб',
  'status': 'planned',
  'status_label': 'Запланировано',
  'is_past': isPast,
  'my_status': myStatus,
  'my_status_label': myStatusLabel,
};

ClubEvent _parsed({
  String title = 'Бизнес-завтрак',
  String format = 'offline',
  String? topic,
  bool isRegistered = false,
}) => ClubEvent.fromJson(
  _event(
    title: title,
    format: format,
    formatLabel: format == 'online' ? 'Онлайн' : 'Очно',
    topic: topic,
    isRegistered: isRegistered,
  ),
);

void main() {
  group('Карточка мероприятия', () {
    test('формат, тема, места, партнёры и фото приходят с сервера', () {
      final e = ClubEvent.fromJson({
        ..._event(
          format: 'online',
          formatLabel: 'Онлайн',
          topic: 'Маркетинг',
          photosCount: 42,
        ),
        'capacity': 30,
        'seats_taken': 25,
        'seats_left': 5,
        'partners': [
          {'id': 3, 'name': 'Кофейня «Зерно»', 'category': 'Кафе'},
        ],
        'photos_link': 'https://disk.yandex.ru/d/abc',
      });

      expect(e.format, 'online');
      expect(e.formatLabel, 'Онлайн');
      expect(e.topic, 'Маркетинг');
      expect(e.capacity, 30);
      expect(e.seatsTaken, 25);
      expect(e.partners.single.name, 'Кофейня «Зерно»');
      expect(e.partners.single.category, 'Кафе');
      expect(e.photosCount, 42);
      expect(e.photosLink, 'https://disk.yandex.ru/d/abc');
    });

    /// Старый сервер этих полей не знает — экран должен жить и без них.
    test('без новых полей разбор не падает', () {
      final e = ClubEvent.fromJson({
        'id': 7,
        'title': 'Минимальное',
        'starts_at': '2026-11-12T09:00:00+00:00',
      });

      expect(e.format, isNull);
      expect(e.topic, isNull);
      expect(e.partners, isEmpty);
      expect(e.photosCount, 0);
      expect(e.photosLink, isNull);
    });

    test('фото: уменьшенная копия для сетки и крупная для просмотра', () {
      final photo = EventPhoto.fromJson({
        'id': 5,
        'thumb_url': 'https://x.test/s.jpg',
        'url': 'https://x.test/l.jpg',
      });

      expect(photo.thumbUrl, 'https://x.test/s.jpg');
      expect(photo.url, 'https://x.test/l.jpg');
    });
  });

  group('Фильтр афиши', () {
    test('пустой фильтр пропускает всё', () {
      expect(EventFilter.none.isEmpty, isTrue);
      expect(EventFilter.none.matches(_parsed()), isTrue);
    });

    test('поиск по названию — без учёта регистра и по части слова', () {
      const filter = EventFilter(query: 'ЗАВТР');

      expect(filter.matches(_parsed(title: 'Бизнес-завтрак')), isTrue);
      expect(filter.matches(_parsed(title: 'Семинар')), isFalse);
      // Пробелы по краям — не часть запроса
      expect(
        const EventFilter(
          query: '  семинар ',
        ).matches(_parsed(title: 'Семинар')),
        isTrue,
      );
    });

    test('формат, тема и «я записан» сужают список вместе', () {
      const filter = EventFilter(
        format: 'online',
        topic: 'Маркетинг',
        mineOnly: true,
      );

      expect(
        filter.matches(
          _parsed(format: 'online', topic: 'Маркетинг', isRegistered: true),
        ),
        isTrue,
      );
      expect(
        filter.matches(_parsed(format: 'online', topic: 'Маркетинг')),
        isFalse,
      );
      expect(
        filter.matches(
          _parsed(format: 'offline', topic: 'Маркетинг', isRegistered: true),
        ),
        isFalse,
      );
    });

    /// Повторное нажатие на выбранный чип снимает его.
    test('повторный выбор снимает формат и тему', () {
      final on = EventFilter.none.toggleFormat('online').toggleTopic('Финансы');
      expect(on.format, 'online');
      expect(on.topic, 'Финансы');

      final off = on.toggleFormat('online').toggleTopic('Финансы');
      expect(off.isEmpty, isTrue);
    });

    test('варианты фильтра берутся из самого списка', () {
      final list = [
        _parsed(format: 'offline', topic: 'Финансы'),
        _parsed(format: 'online', topic: 'Маркетинг'),
        _parsed(format: 'online'),
      ];

      expect(EventFilter.formatsIn(list), {
        'offline': 'Очно',
        'online': 'Онлайн',
      });
      expect(EventFilter.topicsIn(list), ['Маркетинг', 'Финансы']);
    });
  });

  group('Заседания', () {
    test('разбираются вместе с моей отметкой', () {
      final m = Meeting.fromJson(
        _meeting(myStatus: 'present', myStatusLabel: 'Пришёл', isPast: true),
      );

      expect(m.title, 'Заседание клуба');
      expect(m.place, 'Офис экосистемы');
      expect(m.audienceLabel, 'Весь бизнес-клуб');
      expect(m.scheduledAt.hour, 19);
      expect(m.isMarked, isTrue);
      expect(m.wasPresent, isTrue);
    });

    test('неотмеченное прошедшее заседание так и называется', () {
      final m = Meeting.fromJson(_meeting(isPast: true));

      expect(m.isMarked, isFalse);
      expect(m.markLabel, 'Не отмечено');
      expect(
        Meeting.fromJson(
          _meeting(myStatus: 'absent', myStatusLabel: 'Не пришёл'),
        ).markLabel,
        'Не пришёл',
      );
    });
  });

  group('Мои предложения', () {
    test('ждущее решения можно отозвать, рассмотренное — нет', () {
      final pending = EventProposal.fromJson({
        'id': 4,
        'title': 'Разбор воронок',
        'type_label': 'Семинар',
        'format_label': 'Онлайн',
        'starts_at': '2026-11-20T19:00:00+00:00',
        'status': 'pending',
        'status_label': 'На согласовании',
      });
      final rejected = EventProposal.fromJson({
        'id': 5,
        'title': 'Поездка',
        'type_label': 'Бизнес-поездка',
        'format_label': 'Очно',
        'starts_at': '2026-11-20T19:00:00+00:00',
        'status': 'rejected',
        'status_label': 'Отклонено',
        'rejection_reason': 'Пересекается с форумом',
      });

      expect(pending.canWithdraw, isTrue);
      expect(rejected.canWithdraw, isFalse);
      expect(rejected.rejectionReason, 'Пересекается с форумом');
    });
  });

  group('Контроллер событий', () {
    test('заседания грузятся вместе с афишей', () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.path == '/meetings') {
          return (
            200,
            {
              'data': [_meeting()],
              'meta': {
                'attendance': {'held': 0, 'present': 0},
              },
            },
          );
        }
        return (200, {'data': []});
      });
      final c = EventsController(api);

      await c.load();

      expect(c.meetings.single.title, 'Заседание клуба');
      expect(stub.calls.map((x) => x.path), contains('/meetings'));
    });

    /// Заседания — дополнение: их сбой не должен прятать афишу.
    test('сбой заседаний не ломает афишу', () async {
      final (:api, stub: _) = stubbedApi((call) {
        if (call.path == '/meetings') return (403, {'message': 'Нет'});
        if (call.path == '/events') {
          return (
            200,
            {
              'data': [_event()],
            },
          );
        }
        return (200, {'data': []});
      });
      final c = EventsController(api);

      await c.load();

      expect(c.error, isNull);
      expect(c.upcoming, hasLength(1));
      expect(c.meetings, isEmpty);
    });

    test('прошедшие: мероприятия, заседания и посещаемость', () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.path == '/meetings') {
          return (
            200,
            {
              'data': [
                _meeting(
                  myStatus: 'present',
                  myStatusLabel: 'Пришёл',
                  isPast: true,
                ),
              ],
              'meta': {
                'attendance': {'held': 9, 'present': 7},
              },
            },
          );
        }
        return (
          200,
          {
            'data': [_event(isPast: true, photosCount: 12)],
          },
        );
      });
      final c = EventsController(api);

      await c.loadPast();

      expect(c.past.single.photosCount, 12);
      expect(c.pastMeetings.single.wasPresent, isTrue);
      expect(c.attendance.held, 9);
      expect(c.attendance.present, 7);
      expect(
        stub.calls.map((x) => '${x.path}?${x.query['scope']}'),
        containsAll(['/events?past', '/meetings?past']),
      );
    });

    test('месяц календаря: что в какой день', () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.path == '/meetings') {
          return (
            200,
            {
              'data': [
                _meeting(scheduledAt: '2026-11-12T19:00:00+00:00'),
                _meeting(id: 2, scheduledAt: '2026-11-19T19:00:00+00:00'),
              ],
              'meta': {
                'attendance': {'held': 0, 'present': 0},
              },
            },
          );
        }
        return (
          200,
          {
            'data': [_event(startsAt: '2026-11-12T09:00:00+00:00')],
          },
        );
      });
      final c = EventsController(api);

      await c.loadMonth(DateTime(2026, 11, 25));

      expect(c.month, DateTime.utc(2026, 11));
      expect(c.monthEventDays, {12});
      expect(c.monthMeetingDays, {12, 19});
      expect(stub.calls.map((x) => x.query['month']).toSet(), {'2026-11'});
    });

    test('предложение уходит с московским временем без пояса', () async {
      final (:api, :stub) = stubbedApi(
        (call) => (
          201,
          {
            'data': {
              'id': 9,
              'title': 'Разбор воронок',
              'type_label': 'Семинар',
              'format_label': 'Онлайн',
              'starts_at': '2026-11-20T19:00:00+00:00',
              'status': 'pending',
              'status_label': 'На согласовании',
            },
          },
        ),
      );
      final c = EventsController(api);

      await c.propose(
        EventProposalDraft(
          title: 'Разбор воронок',
          type: 'seminar',
          format: 'online',
          topic: 'Маркетинг',
          description: 'Смотрим воронки участников',
          startsAt: DateTime(2026, 11, 20, 19),
          endsAt: DateTime(2026, 11, 20, 21, 30),
          place: null,
          address: null,
          capacity: 20,
        ),
      );

      final body = stub.calls.single.body!;
      expect(stub.calls.single.path, '/events/proposals');
      expect(body['starts_at'], '2026-11-20 19:00');
      expect(body['ends_at'], '2026-11-20 21:30');
      expect(body['capacity'], 20);
      expect(body.containsKey('place'), isFalse);
      expect(c.proposals.single.title, 'Разбор воронок');
    });

    test('отозванное предложение пропадает из списка', () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.method == 'GET') {
          return (
            200,
            {
              'data': [
                {
                  'id': 4,
                  'title': 'Разбор воронок',
                  'type_label': 'Семинар',
                  'format_label': 'Онлайн',
                  'starts_at': '2026-11-20T19:00:00+00:00',
                  'status': 'pending',
                  'status_label': 'На согласовании',
                },
              ],
            },
          );
        }
        return (200, {'data': null});
      });
      final c = EventsController(api);
      await c.loadProposals();

      final error = await c.withdraw(4);

      expect(error, isNull);
      expect(c.proposals, isEmpty);
      expect(stub.calls.last.method, 'DELETE');
      expect(stub.calls.last.path, '/events/proposals/4');
    });

    test('фото мероприятия грузятся по запросу', () async {
      final (:api, :stub) = stubbedApi(
        (call) => (
          200,
          {
            'data': [
              {'id': 1, 'thumb_url': 'https://x.test/1s.jpg', 'url': 'u1'},
              {'id': 2, 'thumb_url': 'https://x.test/2s.jpg', 'url': 'u2'},
            ],
          },
        ),
      );
      final c = EventsController(api);

      final photos = await c.photos(15);

      expect(photos, hasLength(2));
      expect(stub.calls.single.path, '/events/15/photos');
    });

    test('найти мероприятие можно в любом из списков', () async {
      final (:api, stub: _) = stubbedApi((call) => (200, {'data': []}));
      final c = EventsController(api)
        ..past = [ClubEvent.fromJson(_event(id: 77, isPast: true))];

      expect(c.find(77)?.id, 77);
      expect(c.find(78), isNull);
    });
  });
}
