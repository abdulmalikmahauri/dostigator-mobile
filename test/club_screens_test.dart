import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/formatting.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/directory.dart';
import 'package:dostigator/models/resident.dart';
import 'package:dostigator/screens/card_screen.dart';
import 'package:dostigator/screens/directory_screen.dart';
import 'package:dostigator/screens/partner_detail_screen.dart';
import 'package:dostigator/screens/resident_detail_screen.dart';
import 'package:dostigator/screens/residents_list_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/directory_controller.dart';
import 'package:dostigator/state/residents_controller.dart';
import 'package:dostigator/widgets/d_brand_glyphs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/theme.dart';

/// Хранилище в памяти: настоящее лезет в Android Keystore, которого в тестах нет.
class _FakeStorage extends TokenStorage {
  _FakeStorage() : super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

ApiClient _apiThatFails() {
  // Сеть в тестах недоступна — важно, что экраны это переживают
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Хаб «Клуба» без сети: сводка, партнёры и экономия задаются напрямую.
class _FakeDirectoryController extends DirectoryController {
  _FakeDirectoryController() : super(_apiThatFails());

  int? redeemedOfferId;
  int? redeemedAmount;
  String? redeemError;

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<void> ensureLoaded() async {}

  /// Полную карточку резидента не дозапрашиваем — сети в тестах нет.
  @override
  Future<DirectoryEntry?> fetchEntry(int id) async => fullEntry;

  DirectoryEntry? fullEntry;

  @override
  Future<String?> redeem(int offerId, {int? savedAmount}) async {
    redeemedOfferId = offerId;
    redeemedAmount = savedAmount;

    if (redeemError == null) {
      savings = const Savings(total: 140000, confirmed: 125000, count: 3);
      notifyListeners();
    }

    return redeemError;
  }
}

/// Раздел без сети: load ничего не делает, поиск фильтрует локально —
/// так тест проверяет проводку TextField → controller.search → перерисовка,
/// не завися от debounce и Dio.
class _FakeResidentsController extends ResidentsController {
  _FakeResidentsController(ResidentsTier tier) : super(_apiThatFails(), tier);

  List<DirectoryEntry> all = const [];

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  void search(String value) {
    query = value;
    final q = value.toLowerCase().trim();
    residents = q.isEmpty
        ? all
        : all
              .where(
                (e) =>
                    e.name.toLowerCase().contains(q) ||
                    (e.niche ?? '').toLowerCase().contains(q) ||
                    (e.businessName ?? '').toLowerCase().contains(q),
              )
              .toList();
    notifyListeners();
  }

  @override
  void filterByNiche(String? value) {
    niche = value;
    notifyListeners();
  }
}

DirectoryEntry _entry({
  int id = 1,
  String name = 'Аслан Демидов',
  String? niche = 'Логистика',
  bool isMe = false,
  bool isClub = false,
  bool canContact = false,
  String? whatsapp,
  String? telegram,
  String? instagram,
  String? avatarUrl,
  List<Map<String, dynamic>> privileges = const [],
}) {
  return DirectoryEntry.fromJson({
    'id': id,
    'name': name,
    'is_me': isMe,
    'is_club': isClub,
    'can_contact': canContact,
    'avatar_url': avatarUrl,
    'business_name': 'Склад-Сервис',
    'niche': niche,
    'city': 'Грозный',
    'description': 'Оптовая дистрибуция по югу России',
    'can_help': 'Помогу с перевозками',
    'looking_for': 'Ищу подрядчиков',
    'instagram': instagram,
    'whatsapp_url': whatsapp,
    'telegram_url': telegram,
    'privileges': privileges,
  });
}

Partner _partner({
  bool available = true,
  String? minTier,
  Map<String, dynamic>? resident,
}) {
  return Partner.fromJson({
    'id': 1,
    'name': 'Медцентр Пример',
    'category': 'Медицина',
    'address': 'Грозный, центр',
    'resident': resident,
    'offers': [
      {
        'id': 10,
        'title': 'Скидка на диагностику',
        'benefit': '−15%',
        'is_available': available,
        'conditions': 'По карте резидента',
        'valid_until': '2026-12-31',
        'min_tier_label': minTier,
      },
    ],
  });
}

Resident _resident() {
  return Resident.fromJson({
    'id': 1,
    'name': 'Али-Бек Мусаев',
    'phone': '+79000000001',
    'card_number': 'DG-00001',
    'tier_label': 'Бизнес-клуб',
    'is_club_member': true,
    'memberships': const [],
  });
}

Widget _wrap(
  Widget child, {
  required DirectoryController directory,
  ResidentsController? residents,
}) {
  final api = _apiThatFails();

  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: api, tokens: _FakeStorage())
          ..resident = _resident(),
      ),
      ChangeNotifierProvider<DirectoryController>.value(value: directory),
      if (residents != null)
        ChangeNotifierProvider<ResidentsController>.value(value: residents),
    ],
    child: MaterialApp(
      theme: buildDostigatorTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // В приложении Material-предка корневым вкладкам даёт Scaffold
      // из HomeShell — воспроизводим ту же обвязку
      home: Scaffold(body: child),
    ),
  );
}

/// Карта держит Timer.periodic — перед концом теста дерево надо снести,
/// иначе flutter_test падает на «pending timer».
Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// Экраны длиннее тестового окна, а ListView строит только видимое —
/// без высокого окна нижние блоки просто не дойдут до отрисовки.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  group('Клуб — хаб', () {
    testWidgets('два раздела с числами и карта резидента', (tester) async {
      _tallWindow(tester);
      final c = _FakeDirectoryController()
        ..stats = const ClubStats(
          residents: 53,
          club: 12,
          niches: 4,
          partners: 2,
        )
        ..partners = [_partner()];

      await tester.pumpWidget(_wrap(const DirectoryScreen(), directory: c));
      await tester.pump();

      expect(find.text('Бизнес-клуб'), findsWidgets);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Экосистема'), findsOneWidget);
      expect(find.text('53'), findsOneWidget);

      // Карта — с номером и числом привилегий, а не список партнёров
      expect(find.text('DG-00001'), findsOneWidget);
      expect(find.text('1 привилегия'), findsOneWidget);
      expect(find.text('Партнёрские привилегии'), findsNothing);
      expect(find.text('Медцентр Пример'), findsNothing);
    });

    testWidgets('без привилегий карта зовёт показать QR', (tester) async {
      _tallWindow(tester);
      final c = _FakeDirectoryController()
        ..stats = const ClubStats(
          residents: 5,
          club: 2,
          niches: 0,
          partners: 0,
        );

      await tester.pumpWidget(_wrap(const DirectoryScreen(), directory: c));
      await tester.pump();

      expect(find.text('Показать QR'), findsOneWidget);
    });

    testWidgets('раздел открывается отдельным экраном', (tester) async {
      _tallWindow(tester);
      final c = _FakeDirectoryController()
        ..stats = const ClubStats(
          residents: 5,
          club: 2,
          niches: 0,
          partners: 0,
        );

      await tester.pumpWidget(_wrap(const DirectoryScreen(), directory: c));
      await tester.pump();

      await tester.tap(find.text('Экосистема'));
      await tester.pumpAndSettle();

      expect(find.byType(ResidentsListScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Раздел резидентов', () {
    Widget list(_FakeResidentsController c) => _wrap(
      const ResidentsListView(),
      directory: _FakeDirectoryController(),
      residents: c,
    );

    testWidgets('поиск фильтрует список', (tester) async {
      _tallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..all = [
          _entry(id: 1, name: 'Аслан Демидов', niche: 'Логистика'),
          _entry(id: 2, name: 'Хава Ильина', niche: 'Маркетинг'),
        ]
        ..residents = [
          _entry(id: 1, name: 'Аслан Демидов', niche: 'Логистика'),
          _entry(id: 2, name: 'Хава Ильина', niche: 'Маркетинг'),
        ];

      await tester.pumpWidget(list(c));
      await tester.pump();

      expect(find.text('Экосистема'), findsOneWidget);
      expect(find.text('Аслан Демидов'), findsOneWidget);
      expect(find.text('Хава Ильина'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'маркет');
      await tester.pump();

      expect(find.text('Хава Ильина'), findsOneWidget);
      expect(find.text('Аслан Демидов'), findsNothing);
    });

    testWidgets('в экосистеме члены клуба отмечены, в клубе — нет', (
      tester,
    ) async {
      _tallWindow(tester);
      final entries = [
        _entry(id: 1, name: 'Аслан Демидов', isClub: true),
        _entry(id: 2, name: 'Хава Ильина'),
      ];

      await tester.pumpWidget(
        list(
          _FakeResidentsController(ResidentsTier.ecosystem)
            ..residents = entries,
        ),
      );
      await tester.pump();
      expect(find.text('Бизнес-клуб'), findsOneWidget);

      await tester.pumpWidget(
        list(_FakeResidentsController(ResidentsTier.club)..residents = entries),
      );
      await tester.pump();
      // Заголовок экрана — и ни одной метки в строках
      expect(find.text('Бизнес-клуб'), findsOneWidget);
    });

    testWidgets('ecosystem видит подсказку об ограничении контактов', (
      tester,
    ) async {
      _tallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..residents = [_entry()]
        ..seesContacts = false;

      await tester.pumpWidget(list(c));
      await tester.pump();

      expect(
        find.text('Контакты резидентов открыты участникам бизнес-клуба'),
        findsOneWidget,
      );
    });

    testWidgets('участник бизнес-клуба подсказку не видит', (tester) async {
      _tallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.club)
        ..residents = [_entry(canContact: true)]
        ..seesContacts = true;

      await tester.pumpWidget(list(c));
      await tester.pump();

      expect(
        find.text('Контакты резидентов открыты участникам бизнес-клуба'),
        findsNothing,
      );
    });

    testWidgets('собственная карточка помечена «Это вы»', (tester) async {
      _tallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..residents = [_entry(isMe: true), _entry(id: 2, name: 'Хава Ильина')];

      await tester.pumpWidget(list(c));
      await tester.pump();

      expect(find.text('Это вы'), findsOneWidget);
    });
  });

  group('Раздел — длинный список', () {
    // Окно выше обычного: раскрытый список из 20 человек не помещается
    // в тестовый вьюпорт, а ListView строит только видимое.
    void veryTallWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 8000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    List<DirectoryEntry> many(int count) => [
      for (var i = 1; i <= count; i++) _entry(id: i, name: 'Резидент $i'),
    ];

    Widget list(_FakeResidentsController c) => _wrap(
      const ResidentsListView(),
      directory: _FakeDirectoryController(),
      residents: c,
    );

    testWidgets('показывает первых 12, остальных прячет за кнопкой', (
      tester,
    ) async {
      veryTallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..all = many(20)
        ..residents = many(20);

      await tester.pumpWidget(list(c));
      await tester.pump();

      expect(find.text('Резидент 12'), findsOneWidget);
      expect(find.text('Резидент 13'), findsNothing);
      expect(find.text('Показать всех — ещё 8'), findsOneWidget);
    });

    testWidgets('нажатие раскрывает остальных и меняет подпись', (
      tester,
    ) async {
      veryTallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..all = many(20)
        ..residents = many(20);

      await tester.pumpWidget(list(c));
      await tester.pump();

      await tester.tap(find.text('Показать всех — ещё 8'));
      await tester.pump();

      expect(find.text('Резидент 20'), findsOneWidget);
      expect(find.text('Свернуть список'), findsOneWidget);
      expect(find.textContaining('Показать всех'), findsNothing);
    });

    testWidgets('короткий список показывается целиком, без кнопки', (
      tester,
    ) async {
      veryTallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..all = many(5)
        ..residents = many(5);

      await tester.pumpWidget(list(c));
      await tester.pump();

      expect(find.text('Резидент 5'), findsOneWidget);
      expect(find.textContaining('Показать всех'), findsNothing);
    });

    testWidgets('новый поиск снова сворачивает список', (tester) async {
      veryTallWindow(tester);
      final c = _FakeResidentsController(ResidentsTier.ecosystem)
        ..all = many(20)
        ..residents = many(20);

      await tester.pumpWidget(list(c));
      await tester.pump();

      await tester.tap(find.text('Показать всех — ещё 8'));
      await tester.pump();
      expect(find.text('Резидент 20'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'резидент');
      await tester.pump();

      expect(find.text('Резидент 13'), findsNothing);
      expect(find.text('Показать всех — ещё 8'), findsOneWidget);
    });
  });

  group('Карта резидента — привилегии', () {
    testWidgets('экономия показывается раздельно: заявлено и подтверждено', (
      tester,
    ) async {
      _tallWindow(tester);
      final c = _FakeDirectoryController()
        ..partners = [_partner()]
        ..savings = const Savings(total: 140000, confirmed: 125000, count: 3);

      await tester.pumpWidget(_wrap(const ResidentCardScreen(), directory: c));
      await tester.pump();
      // Даём запросу QR упасть и отпустить таймер Dio
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Заявлено резидентом'), findsOneWidget);
      expect(find.text('Подтверждено клубом'), findsOneWidget);
      expect(find.text(Fmt.metric(140000, '₽')), findsOneWidget);
      expect(find.text(Fmt.metric(125000, '₽')), findsOneWidget);
      expect(find.text('Медцентр Пример'), findsOneWidget);

      await _tearDownTree(tester);
    });

    testWidgets('без партнёров — пустое состояние привилегий', (tester) async {
      _tallWindow(tester);
      final c = _FakeDirectoryController();

      await tester.pumpWidget(_wrap(const ResidentCardScreen(), directory: c));
      await tester.pump();
      // Даём запросу QR упасть и отпустить таймер Dio
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Активных предложений пока нет'), findsOneWidget);

      await _tearDownTree(tester);
    });

    testWidgets('привилегия от резидента подписана его именем', (tester) async {
      _tallWindow(tester);
      final c = _FakeDirectoryController()
        ..partners = [
          _partner(resident: {'id': 7, 'name': 'Адам Глебов'}),
        ];

      await tester.pumpWidget(_wrap(const ResidentCardScreen(), directory: c));
      await tester.pump();
      // Даём запросу QR упасть и отпустить таймер Dio
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Скидка на диагностику · Адам Глебов'), findsOneWidget);
      // Инициалы резидента в строке — фото нет
      expect(find.text('АГ'), findsOneWidget);

      await _tearDownTree(tester);
    });
  });

  group('Карточка резидента', () {
    testWidgets('бизнес-клуб: кнопки WhatsApp и Telegram', (tester) async {
      final entry = _entry(
        canContact: true,
        whatsapp: 'https://wa.me/79000001122',
        telegram: 'https://t.me/aslan',
      );

      await tester.pumpWidget(
        _wrap(
          ResidentDetailScreen(entry: entry),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.text('Instagram'), findsNothing);
      expect(
        find.text('Контакты доступны участникам бизнес-клуба'),
        findsNothing,
      );
    });

    testWidgets('ecosystem: спокойный текст вместо мессенджеров', (
      tester,
    ) async {
      final entry = _entry(canContact: false);

      await tester.pumpWidget(
        _wrap(
          ResidentDetailScreen(entry: entry),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(
        find.text('Контакты доступны участникам бизнес-клуба'),
        findsOneWidget,
      );
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Telegram'), findsNothing);
    });

    testWidgets('Instagram виден и экосистеме, если резидент его указал', (
      tester,
    ) async {
      final entry = _entry(canContact: false, instagram: '@aslan.demidov');

      await tester.pumpWidget(
        _wrap(
          ResidentDetailScreen(entry: entry),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(find.text('Instagram'), findsOneWidget);
      expect(find.byType(DInstagramGlyph), findsOneWidget);
    });

    testWidgets('метка клуба и привилегии резидента', (tester) async {
      _tallWindow(tester);
      final entry = _entry(
        isClub: true,
        canContact: true,
        privileges: const [
          {
            'id': 3,
            'partner_id': 1,
            'partner': 'Склад-Сервис',
            'title': 'Скидка на доставку',
            'benefit': '−10%',
            'is_available': true,
          },
        ],
      );

      await tester.pumpWidget(
        _wrap(
          ResidentDetailScreen(entry: entry),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(find.text('Бизнес-клуб'), findsOneWidget);
      expect(find.text('ПРИВИЛЕГИЯ ДЛЯ РЕЗИДЕНТОВ'), findsOneWidget);
      expect(find.text('Скидка на доставку'), findsOneWidget);
      expect(find.text('−10%'), findsOneWidget);
    });

    testWidgets('поля приватности показываются, когда сервер их прислал', (
      tester,
    ) async {
      final entry = _entry(canContact: true);

      await tester.pumpWidget(
        _wrap(
          ResidentDetailScreen(entry: entry),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(find.text('Помогу с перевозками'), findsOneWidget);
      expect(find.text('Ищу подрядчиков'), findsOneWidget);
    });
  });

  group('Привилегия партнёра', () {
    testWidgets('доступный оффер: CTA, диалог суммы и накопитель после', (
      tester,
    ) async {
      final c = _FakeDirectoryController();
      final partner = _partner();

      await tester.pumpWidget(
        _wrap(
          PartnerOfferDetailScreen(
            partner: partner,
            offer: partner.offers.first,
          ),
          directory: c,
        ),
      );
      await tester.pump();

      expect(find.text('−15%'), findsOneWidget);
      expect(find.textContaining('Действует до'), findsOneWidget);

      await tester.tap(find.text('Использовать привилегию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Сколько удалось сэкономить?'), findsOneWidget);
      expect(find.text('Не знаю'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);

      await tester.tap(find.text('Не знаю'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // «Не знаю» отмечает привилегию без суммы
      expect(c.redeemedOfferId, 10);
      expect(c.redeemedAmount, isNull);

      expect(find.text('Заявлено резидентом'), findsOneWidget);
      expect(find.text('Подтверждено клубом'), findsOneWidget);
      // CTA убран — повторное использование не предлагаем
      expect(find.text('Использовать привилегию'), findsNothing);

      // Даём SnackBar закрыться, чтобы не осталось висящих таймеров
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('сумма из диалога уходит в redeem', (tester) async {
      final c = _FakeDirectoryController();
      final partner = _partner();

      await tester.pumpWidget(
        _wrap(
          PartnerOfferDetailScreen(
            partner: partner,
            offer: partner.offers.first,
          ),
          directory: c,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Использовать привилегию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '12000',
      );
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.redeemedAmount, 12000);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('недоступный оффер: чип «Только для бизнес-клуба» вместо CTA', (
      tester,
    ) async {
      final partner = _partner(available: false, minTier: 'Бизнес-клуб');

      await tester.pumpWidget(
        _wrap(
          PartnerOfferDetailScreen(
            partner: partner,
            offer: partner.offers.first,
          ),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(find.text('Только для бизнес-клуба'), findsOneWidget);
      expect(find.text('Использовать привилегию'), findsNothing);
      expect(find.textContaining('Уровень доступа'), findsOneWidget);
    });

    testWidgets('привилегия резидента подписана им', (tester) async {
      final partner = _partner(resident: {'id': 7, 'name': 'Адам Глебов'});

      await tester.pumpWidget(
        _wrap(
          PartnerOfferDetailScreen(
            partner: partner,
            offer: partner.offers.first,
          ),
          directory: _FakeDirectoryController(),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('резидент клуба', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('АГ'), findsOneWidget);
    });
  });
}
