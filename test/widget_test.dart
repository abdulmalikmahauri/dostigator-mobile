import 'package:dostigator/core/formatting.dart';
import 'package:dostigator/models/goal.dart';
import 'package:dostigator/models/resident.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Разбор ответа сервера', () {
    // PHP отдаёт целые значения как int, дробные как double.
    // Прямое приведение к double роняет приложение на первом же экране —
    // ради этого случая модели и читают числа через num.
    test('целые числа в метрике не роняют разбор', () {
      final goal = Goal.fromJson({
        'id': 1,
        'title': 'Выйти на 1,5 млн',
        'metric': {
          'name': 'Прибыль',
          'unit': '₽',
          'from': 900000,
          'target': 1500000,
          'current': 1200000,
        },
        'progress_percent': 50,
        'is_reached': false,
        'deadline': '2026-11-30',
        'days_left': 90,
        'status': 'active',
        'status_label': 'В работе',
        'visibility': 'group',
        'hide_absolute_values': false,
        'checked_in_this_week': false,
        'missed_weeks': 0,
        'steps': [],
        'checkins': [],
      });

      expect(goal.metricFrom, 900000.0);
      expect(goal.metricCurrent, 1200000.0);
      expect(goal.isDecreasing, isFalse);
    });

    test('дробные числа разбираются так же', () {
      final goal = Goal.fromJson({
        'id': 2,
        'title': 'Снизить срок сделки',
        'metric': {
          'name': 'Дней',
          'from': 30.5,
          'target': 15.0,
          'current': 22.25,
        },
        'progress_percent': 53,
        'is_reached': false,
        'deadline': '2026-11-30',
        'days_left': 40,
        'status': 'active',
        'status_label': 'В работе',
        'visibility': 'group',
        'hide_absolute_values': false,
        'checked_in_this_week': true,
        'missed_weeks': 2,
        'steps': [],
        'checkins': [],
      });

      expect(goal.metricCurrent, 22.25);
      expect(goal.isDecreasing, isTrue);
    });

    test('отсутствующие поля не роняют разбор резидента', () {
      final resident = Resident.fromJson({
        'id': 7,
        'name': 'Аслан Демидов',
        'phone': '+79000005122',
        'card_number': 'DG-00007',
        'is_club_member': true,
      });

      expect(resident.name, 'Аслан Демидов');
      expect(resident.memberships, isEmpty);
      expect(resident.profile, isNull);
      expect(resident.initials, 'АД');
    });

    test('долг по взносу находится среди членств', () {
      final resident = Resident.fromJson({
        'id': 7,
        'name': 'Тест',
        'phone': '+79000005122',
        'card_number': 'DG-00007',
        'is_club_member': true,
        'memberships': [
          {
            'tier': 'ecosystem',
            'tier_label': 'Экосистема',
            'status_label': 'Действует',
            'is_overdue': false,
          },
          {
            'tier': 'club',
            'tier_label': 'Бизнес-клуб',
            'status_label': 'Действует',
            'is_overdue': true,
          },
        ],
      });

      expect(resident.overdueMembership?.tier, 'club');
    });
  });

  group('Форматирование по-русски', () {
    test('русские окончания числительных', () {
      expect(Fmt.plural(1, 'день', 'дня', 'дней'), '1 день');
      expect(Fmt.plural(2, 'день', 'дня', 'дней'), '2 дня');
      expect(Fmt.plural(5, 'день', 'дня', 'дней'), '5 дней');
      expect(Fmt.plural(11, 'день', 'дня', 'дней'), '11 дней');
      expect(Fmt.plural(21, 'день', 'дня', 'дней'), '21 день');
      expect(Fmt.plural(112, 'день', 'дня', 'дней'), '112 дней');
    });

    test('крупные суммы полными разрядами', () {
      // Раздел 34 спецификации: полные разряды, «6 240 000 ₽», не «млн»
      // Разряды разделены неразрывным пробелом — сумма не рвётся при переносе
      expect(Fmt.metric(1500000, '₽'), '1 500 000 ₽');
      expect(Fmt.metric(900000, '₽'), contains('₽'));
      expect(Fmt.metric(22, 'дней'), '22 дней');
    });

    test('срок описывается словами', () {
      expect(Fmt.daysLeft(0), 'сегодня последний день');
      expect(Fmt.daysLeft(3), 'осталось 3 дня');
      expect(Fmt.daysLeft(-2), contains('срок вышел'));
    });
  });
}
