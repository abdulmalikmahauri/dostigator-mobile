import 'package:dostigator/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  int id = 1,
  String title = 'Бизнес-завтрак',
  bool isPast = false,
  bool isFull = false,
  bool isAvailable = true,
  bool isRegistered = false,
  bool checkedIn = false,
  int? seatsLeft,
  int? capacity,
  String? ticket,
  String? reason,
  int price = 0,
}) {
  return {
    'id': id,
    'title': title,
    'type': 'breakfast',
    'type_label': 'Бизнес-завтрак',
    'starts_at': '2026-09-20T09:00:00+03:00',
    'price': price,
    'is_free': price == 0,
    'is_past': isPast,
    'capacity': capacity,
    'seats_left': seatsLeft,
    'is_full': isFull,
    'is_available': isAvailable,
    'unavailable_reason': reason,
    'is_registered': isRegistered,
    'checked_in': checkedIn,
    'ticket': ticket,
  };
}

void main() {
  group('Мероприятие', () {
    test('разбирается из ответа сервера', () {
      final e = ClubEvent.fromJson({
        ..._json(seatsLeft: 12, capacity: 30, price: 5000),
        'place': 'Офис экосистемы',
        'speaker': 'Али-Бек Мусаев',
        'description': 'Разбираем задачи участников',
        'min_tier_label': 'Бизнес-клуб',
      });

      expect(e.title, 'Бизнес-завтрак');
      expect(e.typeLabel, 'Бизнес-завтрак');
      expect(e.speaker, 'Али-Бек Мусаев');
      expect(e.minTierLabel, 'Бизнес-клуб');
      expect(e.isFree, isFalse);
      expect(e.price, 5000);
      expect(e.seatsLeft, 12);
    });

    test('записаться можно только когда всё сходится', () {
      expect(ClubEvent.fromJson(_json()).canRegister, isTrue);

      // Прошедшее, заполненное, недоступное по уровню, уже записан
      expect(ClubEvent.fromJson(_json(isPast: true)).canRegister, isFalse);
      expect(ClubEvent.fromJson(_json(isFull: true)).canRegister, isFalse);
      expect(
        ClubEvent.fromJson(_json(isAvailable: false)).canRegister,
        isFalse,
      );
      expect(
        ClubEvent.fromJson(_json(isRegistered: true)).canRegister,
        isFalse,
      );
    });

    /// «Осталось 12 мест» никого не торопит, «осталось 3» — торопит.
    test('предупреждение о нехватке мест включается у порога', () {
      expect(ClubEvent.fromJson(_json(seatsLeft: 12)).isRunningOut, isFalse);
      expect(ClubEvent.fromJson(_json(seatsLeft: 3)).isRunningOut, isTrue);
      expect(ClubEvent.fromJson(_json(seatsLeft: 1)).isRunningOut, isTrue);

      // Ноль мест — это уже не «заканчиваются», а «нет»
      expect(ClubEvent.fromJson(_json(seatsLeft: 0)).isRunningOut, isFalse);

      // Без ограничения мест предупреждать не о чем
      expect(ClubEvent.fromJson(_json()).isRunningOut, isFalse);
    });

    test('причина недоступности сохраняется для показа', () {
      final e = ClubEvent.fromJson(
        _json(isAvailable: false, reason: 'Только для резидентов бизнес-клуба'),
      );

      expect(e.canRegister, isFalse);
      expect(e.unavailableReason, 'Только для резидентов бизнес-клуба');
    });

    test('билет отдаётся только своей записи', () {
      final mine = ClubEvent.fromJson(
        _json(isRegistered: true, ticket: 'a' * 32),
      );
      final other = ClubEvent.fromJson(_json());

      expect(mine.ticket, hasLength(32));
      expect(other.ticket, isNull);
    });

    test('отмеченный на входе виден отдельно от просто записанного', () {
      final e = ClubEvent.fromJson(
        _json(isRegistered: true, checkedIn: true, ticket: 'b' * 32),
      );

      expect(e.isRegistered, isTrue);
      expect(e.checkedIn, isTrue);
    });

    test('неполный ответ не роняет разбор', () {
      final e = ClubEvent.fromJson({
        'id': 7,
        'title': 'Минимальное',
        'starts_at': '2026-09-20T09:00:00+03:00',
      });

      expect(e.typeLabel, 'Мероприятие');
      expect(e.isFree, isTrue);
      expect(e.seatsLeft, isNull);
      expect(e.isAvailable, isTrue);
      expect(e.place, isNull);
    });
  });
}
