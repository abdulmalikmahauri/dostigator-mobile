import 'package:dostigator/models/directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Каталог резидентов', () {
    test('полная карточка разбирается', () {
      final e = DirectoryEntry.fromJson({
        'id': 5,
        'name': 'Аслан Демидов',
        'city': 'Грозный',
        'tier_label': 'Бизнес-клуб',
        'is_me': false,
        'business_name': 'Склад-Сервис',
        'niche': 'Логистика',
        'can_help': 'Помогу с перевозками',
        'looking_for': 'Ищу подрядчиков',
        'employees_count': 25,
        'can_contact': true,
        'whatsapp_url': 'https://wa.me/79000001122',
        'telegram_url': 'https://t.me/aslan',
      });

      expect(e.name, 'Аслан Демидов');
      expect(e.canContact, isTrue);
      expect(e.whatsappUrl, contains('wa.me'));
      expect(e.employeesCount, 25);
    });

    /// Сервер уже вырезал скрытые поля — приложение ничего не решает само
    /// и не должно спотыкаться о null там, где раньше была строка.
    test('карточка со скрытыми полями не роняет разбор', () {
      final e = DirectoryEntry.fromJson({
        'id': 6,
        'name': 'Скрытный Резидент',
        'is_me': false,
        'can_contact': false,
        'looking_for': null,
        'employees_count': null,
        'whatsapp_url': null,
        'telegram_url': null,
      });

      expect(e.lookingFor, isNull);
      expect(e.employeesCount, isNull);
      expect(e.canContact, isFalse);
      expect(e.whatsappUrl, isNull);
    });

    test('инициалы собираются из имени и фамилии', () {
      expect(
        DirectoryEntry.fromJson({'id': 1, 'name': 'Аслан Демидов'}).initials,
        'АД',
      );
      expect(DirectoryEntry.fromJson({'id': 2, 'name': 'Хава'}).initials, 'Х');
      expect(DirectoryEntry.fromJson({'id': 3, 'name': ''}).initials, '—');

      // Отчество не должно ломать вычисление
      expect(
        DirectoryEntry.fromJson({
          'id': 4,
          'name': 'Али-Бек Мусаев Русланович',
        }).initials,
        'АМ',
      );
    });
  });

  group('Привилегии', () {
    test('партнёр с привилегиями разбирается', () {
      final p = Partner.fromJson({
        'id': 1,
        'name': 'Медцентр Пример',
        'category': 'Медицина',
        'address': 'Грозный, центр',
        'offers': [
          {
            'id': 10,
            'title': 'Скидка на диагностику',
            'benefit': '−15%',
            'is_available': true,
            'conditions': 'По карте резидента',
          },
          {
            'id': 11,
            'title': 'Закрытая программа',
            'benefit': '−5 000 ₽',
            'is_available': false,
            'min_tier_label': 'Бизнес-клуб',
          },
        ],
      });

      expect(p.name, 'Медцентр Пример');
      expect(p.offers, hasLength(2));
      expect(p.offers[0].benefit, '−15%');
      expect(p.offers[0].isAvailable, isTrue);

      // Недоступная видна, но помечена — это аргумент апгрейда членства
      expect(p.offers[1].isAvailable, isFalse);
      expect(p.offers[1].minTierLabel, 'Бизнес-клуб');
    });

    test('партнёр без привилегий разбирается пустым списком', () {
      final p = Partner.fromJson({'id': 2, 'name': 'Без привилегий'});

      expect(p.offers, isEmpty);
      expect(p.category, isNull);
    });

    test('накопитель экономии разделяет подтверждённое и заявленное', () {
      final s = Savings.fromJson({
        'total': 12000,
        'confirmed': 5000,
        'count': 3,
      });

      expect(s.total, 12000);
      expect(s.confirmed, 5000);
      expect(s.count, 3);
    });

    test('пустой накопитель не роняет разбор', () {
      expect(Savings.fromJson(const {}).total, 0);
      expect(Savings.empty.count, 0);
    });
  });

  group('Instagram и привилегии резидента', () {
    DirectoryEntry entry(String? instagram) => DirectoryEntry.fromJson({
      'id': 1,
      'name': 'Аслан Демидов',
      'is_me': false,
      'can_contact': false,
      'instagram': instagram,
    });

    test('ссылка собирается из любого написания', () {
      expect(
        entry('@aslan.demidov').instagramUrl,
        'https://instagram.com/aslan.demidov',
      );
      expect(entry('aslan_d').instagramUrl, 'https://instagram.com/aslan_d');
      expect(
        entry('https://www.instagram.com/aslan.d/?igsh=1').instagramUrl,
        'https://instagram.com/aslan.d',
      );
      expect(
        entry('instagram.com/aslan.d/').instagramUrl,
        'https://instagram.com/aslan.d',
      );
    });

    test('пустое и мусорное значение — без кнопки', () {
      expect(entry(null).instagramUrl, isNull);
      expect(entry('   ').instagramUrl, isNull);
      expect(entry('@').instagramUrl, isNull);
    });

    test('метка клуба, фото и привилегии разбираются', () {
      final e = DirectoryEntry.fromJson({
        'id': 1,
        'name': 'Адам Глебов',
        'is_me': false,
        'is_club': true,
        'can_contact': true,
        'avatar_url': 'https://x/storage/avatars/a.jpg',
        'privileges': [
          {
            'id': 3,
            'partner_id': 9,
            'partner': 'Клиника Адама',
            'title': 'Скидка на приём',
            'benefit': '−20%',
            'is_available': true,
            'conditions': 'По карте',
          },
        ],
      });

      expect(e.isClub, isTrue);
      expect(e.avatarUrl, endsWith('/avatars/a.jpg'));
      expect(e.privileges, hasLength(1));
      expect(e.privileges.first.partner, 'Клиника Адама');
      expect(e.privileges.first.benefit, '−20%');
      expect(e.privileges.first.conditions, 'По карте');
    });

    test('старый ответ без новых полей не ломает разбор', () {
      final e = DirectoryEntry.fromJson({
        'id': 1,
        'name': 'Аслан',
        'is_me': false,
        'can_contact': false,
      });

      expect(e.isClub, isFalse);
      expect(e.avatarUrl, isNull);
      expect(e.privileges, isEmpty);
    });
  });

  group('Партнёр-резидент и сводка', () {
    test('резидент у партнёра разбирается, у внешнего — null', () {
      final own = Partner.fromJson({
        'id': 1,
        'name': 'Клиника Адама',
        'resident': {'id': 7, 'name': 'Адам Глебов', 'avatar_url': null},
        'offers': [],
      });
      final external = Partner.fromJson({
        'id': 2,
        'name': 'Медцентр Пример',
        'offers': [],
      });

      expect(own.resident?.id, 7);
      expect(own.resident?.name, 'Адам Глебов');
      expect(external.resident, isNull);
    });

    test('сводка считает клуб отдельно', () {
      final s = ClubStats.fromJson({
        'residents': 53,
        'club': 12,
        'niches': 4,
        'partners': 2,
      });

      expect(s.residents, 53);
      expect(s.club, 12);
      expect(s.isEmpty, isFalse);
      expect(ClubStats.fromJson({}).club, 0);
    });
  });
}
