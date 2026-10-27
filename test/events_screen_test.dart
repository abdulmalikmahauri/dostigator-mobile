import 'package:dostigator/models/event.dart';
import 'package:dostigator/models/meeting.dart';
import 'package:dostigator/screens/event_detail_screen.dart';
import 'package:dostigator/screens/events_screen.dart';
import 'package:dostigator/widgets/d_qr_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api.dart';
import 'helpers/events.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  group('События — афиша', () {
    testWidgets('открытая запись: ближайшее событие и активная кнопка', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [testEvent(seatsLeft: 10, place: 'Офис экосистемы')];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('БЛИЖАЙШЕЕ СОБЫТИЕ'), findsOneWidget);
      expect(find.text('Бизнес-завтрак'), findsOneWidget);
      expect(find.text('Офис экосистемы'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Записаться'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('места в большой карточке — сколько осталось из скольких', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [testEvent(seatsLeft: 5, capacity: 30)];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Осталось 5 мест из 30'), findsOneWidget);
    });

    testWidgets('мест нет: кнопка записи выключена', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [testEvent(isFull: true, seatsLeft: 0)];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Мест нет'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Записаться'), findsNothing);
    });

    /// Раздел 28: закрытое событие видно, но с честной пометкой об уровне.
    testWidgets('только клуб: событие не скрыто, записи нет', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [testEvent(isAvailable: false, title: 'Закрытая встреча')];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Закрытая встреча'), findsOneWidget);
      expect(find.text('Только для бизнес-клуба'), findsOneWidget);
      expect(find.text('Записаться'), findsNothing);
    });

    testWidgets('зарегистрирован: статус, кнопка билета и мини-QR', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final registered = testEvent(
        isRegistered: true,
        ticket: 'DG-TICKET-0001',
      );
      final events = StubEventsController(api)
        ..upcoming = [registered]
        ..mine = [registered];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Вы идёте'), findsOneWidget);
      expect(find.text('Открыть билет'), findsOneWidget);
      expect(find.text('МОЙ БИЛЕТ'), findsOneWidget);
      expect(find.byType(DQrCard), findsOneWidget);
    });

    testWidgets('чипы статусов в списке других событий', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [
          testEvent(id: 1, title: 'Ближайшее'),
          testEvent(
            id: 2,
            title: 'Заполненное',
            isFull: true,
            startsAt: '2026-09-21T09:00:00+03:00',
          ),
          testEvent(
            id: 3,
            title: 'Почти полное',
            seatsLeft: 2,
            startsAt: '2026-09-22T09:00:00+03:00',
          ),
          testEvent(
            id: 4,
            title: 'Закрытое',
            isAvailable: false,
            startsAt: '2026-09-23T09:00:00+03:00',
          ),
          testEvent(
            id: 5,
            title: 'Свободное',
            seatsLeft: 20,
            startsAt: '2026-09-24T09:00:00+03:00',
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ДРУГИЕ СОБЫТИЯ'), findsOneWidget);
      expect(find.text('Мест нет'), findsOneWidget);
      expect(find.text('Мест мало'), findsOneWidget);
      expect(find.text('Только клуб'), findsOneWidget);
      expect(find.text('Открыта запись'), findsOneWidget);
    });

    testWidgets('без событий показывается пустое состояние', (tester) async {
      final api = unreachableApi();
      final events = StubEventsController(api);

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Ближайших событий пока нет'), findsOneWidget);
    });

    testWidgets('поиск по названию оставляет только найденное', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [
          testEvent(id: 1, title: 'Бизнес-завтрак'),
          testEvent(
            id: 2,
            title: 'Семинар по продажам',
            startsAt: '2026-09-21T09:00:00+03:00',
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'семинар');
      await tester.pump();

      expect(find.text('Семинар по продажам'), findsOneWidget);
      expect(find.text('Бизнес-завтрак'), findsNothing);
      // В режиме поиска нет «ближайшего» — только найденное
      expect(find.text('БЛИЖАЙШЕЕ СОБЫТИЕ'), findsNothing);
    });

    testWidgets('ничего не нашлось — фильтр можно сбросить одним нажатием', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)..upcoming = [testEvent()];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(find.byType(TextField), 'форум');
      await tester.pump();
      expect(find.text('Ничего не нашлось'), findsOneWidget);

      await tester.tap(find.text('Сбросить фильтр'));
      await tester.pump();

      expect(find.text('Бизнес-завтрак'), findsOneWidget);
      expect(events.filter.isEmpty, isTrue);
    });

    testWidgets('«Я записан», формат и тема — чипами над афишей', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [
          testEvent(id: 1, title: 'Очный завтрак', topic: 'Финансы'),
          testEvent(
            id: 2,
            title: 'Онлайн-разбор',
            format: 'online',
            topic: 'Маркетинг',
            isRegistered: true,
            startsAt: '2026-09-21T09:00:00+03:00',
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Я записан'), findsOneWidget);
      expect(find.text('Онлайн'), findsOneWidget);
      // Полосу чипов листают пальцем: последний может быть за краем
      expect(find.text('Финансы', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Маркетинг'));
      await tester.pump();

      expect(find.text('Онлайн-разбор'), findsOneWidget);
      expect(find.text('Очный завтрак'), findsNothing);

      // Повторное нажатие снимает тему, «Я записан» оставляет своё
      await tester.tap(find.text('Маркетинг'));
      await tester.pump();
      await tester.tap(find.text('Я записан'));
      await tester.pump();

      expect(find.text('Онлайн-разбор'), findsOneWidget);
      expect(find.text('Очный завтрак'), findsNothing);
    });

    testWidgets('ближайшие заседания видны в афише', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..upcoming = [testEvent()]
        ..meetings = [testMeeting(title: 'Заседание группы «Альфа»')];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ЗАСЕДАНИЯ'), findsOneWidget);
      expect(find.text('Заседание группы «Альфа»'), findsOneWidget);
      expect(find.textContaining('12 ноября'), findsOneWidget);
    });

    testWidgets('из афиши можно предложить своё мероприятие', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)..upcoming = [testEvent()];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Мои предложения'), findsOneWidget);
      await tester.tap(find.text('Предложить мероприятие'));
      await tester.pumpAndSettle();

      expect(find.text('Отправить организаторам'), findsOneWidget);
    });
  });

  group('События — прошедшие', () {
    testWidgets('мероприятия с отметкой посещения и фото', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..pastLoaded = true
        ..past = [
          testEvent(
            id: 10,
            title: 'Был здесь',
            isPast: true,
            checkedIn: true,
            isRegistered: true,
            startsAt: '2026-05-15T19:00:00+03:00',
          ),
          testEvent(
            id: 11,
            title: 'Пропустил',
            isPast: true,
            isRegistered: true,
            startsAt: '2026-06-10T19:00:00+03:00',
          ),
          testEvent(
            id: 12,
            title: 'Форум без меня',
            isPast: true,
            photosCount: 40,
            startsAt: '2026-06-20T19:00:00+03:00',
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Прошедшие'));
      await tester.pump();

      expect(find.text('Был'), findsOneWidget);
      expect(find.text('Не был'), findsOneWidget);
      expect(find.text('40 фото'), findsOneWidget);
    });

    testWidgets('заседания: моя отметка и посещаемость', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..pastLoaded = true
        ..attendance = const MeetingAttendance(held: 9, present: 7)
        ..pastMeetings = [
          testMeeting(
            id: 1,
            isPast: true,
            myStatus: 'present',
            myStatusLabel: 'Пришёл',
          ),
          testMeeting(
            id: 2,
            isPast: true,
            scheduledAt: '2026-11-05T19:00:00+00:00',
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Прошедшие'));
      await tester.pump();

      expect(find.text('7 из 9'), findsOneWidget);
      expect(find.text('Пришёл'), findsOneWidget);
      expect(find.text('Не отмечено'), findsOneWidget);
    });

    testWidgets('архив грузится, только когда его открыли', (tester) async {
      final api = unreachableApi();
      final events = StubEventsController(api);

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(events.pastLoads, 0);

      await tester.tap(find.text('Прошедшие'));
      await tester.pump();

      expect(events.pastLoads, 1);
    });
  });

  group('События — календарь', () {
    testWidgets('день в календаре показывает его мероприятия и заседания', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..month = DateTime.utc(2026, 11)
        ..monthEvents = [
          testEvent(title: 'Завтрак 12-го', startsAt: '2026-11-12T09:00:00Z'),
          testEvent(
            id: 2,
            title: 'Семинар 20-го',
            startsAt: '2026-11-20T18:00:00Z',
          ),
        ]
        ..monthMeetings = [testMeeting(title: 'Заседание 12-го')];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Календарь'));
      await tester.pump();

      expect(find.text('Ноябрь 2026'), findsOneWidget);
      // Без выбранного дня — весь месяц
      expect(find.text('Семинар 20-го'), findsOneWidget);

      await tester.tap(find.text('12'));
      await tester.pump();

      expect(find.text('Завтрак 12-го'), findsOneWidget);
      expect(find.text('Заседание 12-го'), findsOneWidget);
      expect(find.text('Семинар 20-го'), findsNothing);
    });

    testWidgets('запись видна в календаре сразу, без перелистывания', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final stale = testEvent(
        title: 'Завтрак',
        startsAt: '2026-11-12T09:00:00Z',
      );
      final events = StubEventsController(api)
        ..month = DateTime.utc(2026, 11)
        ..monthEvents = [stale]
        // После записи свежая копия есть в «моих», а месяц ещё старый
        ..mine = [
          testEvent(
            title: 'Завтрак',
            startsAt: '2026-11-12T09:00:00Z',
            isRegistered: true,
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Календарь'));
      await tester.pump();

      expect(find.text('Вы идёте'), findsOneWidget);
    });

    testWidgets('у прошедшего в календаре — был или не был, а не «Вы идёте»', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)
        ..month = DateTime.utc(2026, 11)
        ..monthEvents = [
          testEvent(
            id: 1,
            title: 'Был на завтраке',
            startsAt: '2026-11-02T09:00:00Z',
            isPast: true,
            isRegistered: true,
            checkedIn: true,
          ),
          testEvent(
            id: 2,
            title: 'Пропустил семинар',
            startsAt: '2026-11-03T18:00:00Z',
            isPast: true,
            isRegistered: true,
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Календарь'));
      await tester.pump();

      expect(find.text('Был'), findsOneWidget);
      expect(find.text('Не был'), findsOneWidget);
      expect(find.text('Вы идёте'), findsNothing);
    });

    testWidgets('стрелки листают месяцы', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final events = StubEventsController(api)..month = DateTime.utc(2026, 11);

      await tester.pumpWidget(
        wrapEvents(const EventsScreen(), events: events, api: api),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Календарь'));
      await tester.pump();

      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pump();

      expect(events.monthsLoaded.last.month, 12);
      expect(find.text('Декабрь 2026'), findsOneWidget);
    });
  });

  group('Детали события', () {
    testWidgets('открытая запись: факты и активная кнопка', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(
        seatsLeft: 3,
        place: 'Офис экосистемы',
        description: 'Разбираем задачи участников.',
        speaker: 'Али-Бек Мусаев',
      );
      final events = StubEventsController(api)..upcoming = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Событие'), findsOneWidget);
      expect(find.text('Бизнес-завтрак'), findsOneWidget);
      expect(find.text('Разбираем задачи участников.'), findsOneWidget);
      expect(find.text('Али-Бек Мусаев'), findsOneWidget);
      expect(find.textContaining('Осталось'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Записаться'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('зарегистрирован: билет с QR, кодом и отменой', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(isRegistered: true, ticket: 'DG-TICKET-0001');
      final events = StubEventsController(api)..mine = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Вы зарегистрированы'), findsOneWidget);
      expect(find.byType(DQrCard), findsOneWidget);
      expect(find.text('Покажите на входе'), findsOneWidget);
      // Код продублирован текстом — сканера на входе может не быть
      expect(
        find.widgetWithText(SelectableText, 'DG-TICKET-0001'),
        findsOneWidget,
      );
      expect(find.text('Отменить запись'), findsOneWidget);
      // Записываться уже некуда
      expect(find.text('Записаться'), findsNothing);
    });

    testWidgets('после check-in: статус вместо билета и отмены', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(
        isRegistered: true,
        checkedIn: true,
        ticket: 'DG-TICKET-0001',
      );
      final events = StubEventsController(api)..mine = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Отмечен на входе'), findsOneWidget);
      expect(find.text('Отменить запись'), findsNothing);
    });

    testWidgets('мест нет: выключенная кнопка внизу', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(isFull: true, seatsLeft: 0);
      final events = StubEventsController(api)..upcoming = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Мест нет'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('только клуб: пометка и никаких кнопок записи', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(isAvailable: false);
      final events = StubEventsController(api)..upcoming = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Только для бизнес-клуба'), findsOneWidget);
      expect(find.text('Записаться'), findsNothing);
      expect(find.text('Мест нет'), findsNothing);
    });

    /// Во время запроса повторный tap запрещён (раздел 40).
    testWidgets('во время запроса кнопка записи заблокирована', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(seatsLeft: 5);
      final events = StubEventsController(api)
        ..upcoming = [event]
        ..busyEventId = event.id;

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Кнопка в состоянии loading: спиннер вместо текста, нажатие запрещено
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets('места: сколько осталось из скольких', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(seatsLeft: 5, capacity: 30);
      final events = StubEventsController(api)..upcoming = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Осталось 5 мест из 30'), findsOneWidget);
    });

    testWidgets('формат, тема и партнёры мероприятия', (tester) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(
        format: 'online',
        topic: 'Маркетинг',
        partners: [
          {'id': 3, 'name': 'Кофейня «Зерно»', 'category': 'Кафе'},
        ],
      );
      final events = StubEventsController(api)..upcoming = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Онлайн'), findsOneWidget);
      expect(find.textContaining('Маркетинг'), findsOneWidget);
      expect(find.text('ПАРТНЁРЫ'), findsOneWidget);
      expect(find.text('Кофейня «Зерно»'), findsOneWidget);
      expect(find.text('Кафе'), findsOneWidget);
    });

    testWidgets('прошедшее с фото: сетка превью и ссылка на всю папку', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(
        isPast: true,
        photosCount: 2,
        photosLink: 'https://disk.yandex.ru/d/abc',
      );
      final events = StubEventsController(api)
        ..past = [event]
        ..photosResult = [
          EventPhoto.fromJson(const {
            'id': 1,
            'thumb_url': 'https://x.test/1s.jpg',
            'url': 'https://x.test/1.jpg',
          }),
          EventPhoto.fromJson(const {
            'id': 2,
            'thumb_url': 'https://x.test/2s.jpg',
            'url': 'https://x.test/2.jpg',
          }),
        ];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ФОТО'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Фото 1 из 2')), findsOneWidget);
      expect(find.text('Все фото на Яндекс Диске'), findsOneWidget);
      // Прошедшее — записываться некуда
      expect(find.text('Записаться'), findsNothing);
    });

    testWidgets('прошедшее, на которое был записан, без билета и отмены', (
      tester,
    ) async {
      tallWindow(tester);
      final api = unreachableApi();
      final event = testEvent(
        isPast: true,
        isRegistered: true,
        ticket: 'DG-TICKET-0001',
      );
      final events = StubEventsController(api)..mine = [event];

      await tester.pumpWidget(
        wrapEvents(
          EventDetailScreen(event: event),
          events: events,
          api: api,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Отменить запись'), findsNothing);
      expect(find.byType(DQrCard), findsNothing);
    });
  });
}
