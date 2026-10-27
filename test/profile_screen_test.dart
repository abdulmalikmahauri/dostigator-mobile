import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/api_config.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/resident.dart';
import 'package:dostigator/screens/card_screen.dart';
import 'package:dostigator/screens/photo_view_screen.dart';
import 'package:dostigator/screens/profile_edit_screen.dart';
import 'package:dostigator/screens/profile_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/goals_controller.dart';
import 'package:dostigator/widgets/d_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/directory.dart';
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

/// Управляемые ответы сервера: запросы никуда не уходят, а тест задаёт,
/// что именно вернул бэкенд на каждый путь.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  /// Путь и метод -> (код ответа, тело). Всё неописанное — пустой список.
  final (int, Map<String, dynamic>) Function(RequestOptions options) handler;

  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    final (code, body) = handler(options);

    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient api, _StubAdapter stub}) _apiWithStub(
  (int, Map<String, dynamic>) Function(RequestOptions) handler,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://stub.test/api/v1',
      // Как в боевом клиенте: отказ сервера — это ответ, а не сбой сети
      validateStatus: (code) => code != null && code < 500,
    ),
  );
  final stub = _StubAdapter(handler);
  dio.httpClientAdapter = stub;

  return (api: ApiClient(tokens: _FakeStorage(), dio: dio), stub: stub);
}

ApiClient _apiThatFails() {
  // Сеть в тестах недоступна — важно, что экран это переживает,
  // а не падает с красным экраном.
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Что видно другим, если резидент ничего не менял: умолчания сервера.
const _defaultVisibility = {
  'description': true,
  'can_help': true,
  'looking_for': false,
  'employees_count': false,
  'website': true,
  'instagram': true,
  'contacts': true,
};

Map<String, dynamic> _residentJson({
  bool overdue = false,
  bool withProfile = false,
  String? paidUntil,
  String? avatarUrl,
  Map<String, bool>? visibility,
}) {
  return {
    'id': 1,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    'name': 'Али-Бек Мусаев',
    'phone': '+79000000001',
    'phone_pretty': '+7 900 000-00-01',
    'card_number': 'DG-00001',
    'tier_label': 'Бизнес-клуб',
    'is_club_member': true,
    'city': 'Грозный',
    'memberships': [
      {
        'tier': 'club',
        'tier_label': 'Бизнес-клуб',
        // Просроченному членству оставляем пустой статус: экран обязан
        // подставить понятную подпись сам, а не показать пустой чип
        'status_label': overdue ? '' : 'Действует',
        'is_overdue': overdue,
        if (paidUntil != null) 'paid_until': paidUntil,
      },
    ],
    if (withProfile || visibility != null)
      'profile': {
        if (withProfile) ...{
          'business_name': 'Мясной цех «Пример»',
          'niche': 'Производство продуктов',
          'description': 'Полутуши и полуфабрикаты для HoReCa',
          'can_help': 'Выходом на розничные сети',
          'looking_for': 'Логиста по СКФО',
        },
        'visibility': visibility ?? _defaultVisibility,
      },
  };
}

Resident _resident({
  bool overdue = false,
  bool withProfile = false,
  String? paidUntil,
  String? avatarUrl,
  Map<String, bool>? visibility,
}) {
  return Resident.fromJson(
    _residentJson(
      overdue: overdue,
      withProfile: withProfile,
      paidUntil: paidUntil,
      avatarUrl: avatarUrl,
      visibility: visibility,
    ),
  );
}

Widget _wrap({AuthController? auth, GoalsController? goals, ApiClient? api}) {
  final client = api ?? _apiThatFails();

  return MultiProvider(
    providers: [
      themeProvider(),
      directoryProvider(),
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<AuthController>.value(
        value: auth ?? AuthController(api: client, tokens: _FakeStorage()),
      ),
      ChangeNotifierProvider<GoalsController>.value(
        value: goals ?? GoalsController(client),
      ),
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
      home: const ProfileScreen(),
    ),
  );
}

/// Канал flutter_local_notifications. Без заглушки блок напоминаний
/// уходит в MissingPluginException — тест обязан управлять разрешением.
const _notifChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

bool _notifGranted = true;
List<Map<String, Object?>> _pendingReminders = const [];

void _mockNotifications() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_notifChannel, (call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'areNotificationsEnabled':
            return _notifGranted;
          case 'requestNotificationsPermission':
            _notifGranted = true;
            return true;
          case 'pendingNotificationRequests':
            return _pendingReminders;
          default:
            return null;
        }
      });
}

/// Экран длиннее окна теста по умолчанию, а ListView строит только видимое —
/// без высокого окна нижние блоки просто не дойдут до отрисовки.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);

    // В тестах platform-registrant плагинов не выполняется, поэтому
    // экземпляр платформы уведомлений назначаем вручную — дальше все
    // его вызовы перехватывает заглушка канала из _mockNotifications
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
  });

  setUp(() {
    _notifGranted = true;
    _pendingReminders = const [];
    _mockNotifications();
  });

  testWidgets('профиль показывает имя, телефон, город и членство', (
    tester,
  ) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident(paidUntil: '2026-12-31');

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Али-Бек Мусаев'), findsOneWidget);
    expect(find.text('+7 900 000-00-01'), findsOneWidget);
    expect(find.text('Грозный'), findsOneWidget);
    expect(find.text('Бизнес-клуб'), findsOneWidget);
    expect(find.text('Действует'), findsOneWidget);
    expect(find.textContaining('Оплачен до'), findsOneWidget);
    // Взнос в порядке — предупреждения быть не должно
    expect(find.text('Взнос не оплачен'), findsNothing);
  });

  testWidgets('долг по взносу подсвечен предупреждением', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident(overdue: true);

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Взнос не оплачен'), findsOneWidget);
  });

  testWidgets('бизнес-профиль выводит поля резидента', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident(withProfile: true);

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Мясной цех «Пример»'), findsOneWidget);
    expect(find.text('Производство продуктов'), findsOneWidget);
    // Подписи встречаются дважды: в самом профиле и в блоке приватности
    expect(find.text('Чем могу быть полезен'), findsNWidgets(2));
    expect(find.text('Выходом на розничные сети'), findsOneWidget);
    expect(find.text('Что ищу'), findsNWidgets(2));
    expect(find.text('Логиста по СКФО'), findsOneWidget);
  });

  testWidgets('без бизнес-профиля показывается заглушка', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.textContaining('Бизнес-профиль пока не заполнен'),
      findsOneWidget,
    );
  });

  group('Свои данные', () {
    testWidgets('из профиля открывается правка данных', (tester) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final auth = AuthController(api: api, tokens: _FakeStorage())
        ..resident = _resident(withProfile: true);

      await tester.pumpWidget(_wrap(auth: auth, api: api));
      await tester.pump(const Duration(seconds: 1));

      // Раньше здесь стояло «изменить данные можно через организатора»
      expect(find.textContaining('через организатора'), findsNothing);

      await tester.tap(find.text('Изменить данные'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ProfileEditScreen), findsOneWidget);
    });

    testWidgets('пустой профиль предлагает заполнить его самому', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final auth = AuthController(api: api, tokens: _FakeStorage())
        ..resident = _resident();

      await tester.pumpWidget(_wrap(auth: auth, api: api));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Заполнить профиль'), findsOneWidget);
    });
  });

  group('Приватность', () {
    Switch toggle(WidgetTester tester, String field) =>
        tester.widget<Switch>(find.byKey(Key('visibility-$field')));

    /// Раньше здесь была одна строка: «видимость настраивает организатор».
    testWidgets('переключатели показывают, что сейчас видно другим', (
      tester,
    ) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final auth = AuthController(api: api, tokens: _FakeStorage())
        ..resident = _resident(withProfile: true);

      await tester.pumpWidget(_wrap(auth: auth, api: api));
      await tester.pump(const Duration(seconds: 1));

      expect(toggle(tester, 'contacts').value, isTrue);
      expect(toggle(tester, 'can_help').value, isTrue);
      expect(toggle(tester, 'looking_for').value, isFalse);
      expect(toggle(tester, 'employees_count').value, isFalse);

      expect(find.textContaining('настраивает организатор'), findsNothing);
    });

    testWidgets('переключение уходит на сервер одним полем', (tester) async {
      _tallWindow(tester);
      Map<String, dynamic>? sent;
      final h = _apiWithStub((o) {
        if (o.method == 'PATCH' && o.path == '/me') {
          sent = o.data as Map<String, dynamic>;

          return (
            200,
            {
              'data': _residentJson(
                withProfile: true,
                visibility: {..._defaultVisibility, 'looking_for': true},
              ),
            },
          );
        }
        return (200, {'data': null});
      });
      final auth = AuthController(api: h.api, tokens: _FakeStorage())
        ..resident = _resident(withProfile: true);

      await tester.pumpWidget(_wrap(auth: auth, api: h.api));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const Key('visibility-looking_for')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sent, {
        'visibility': {'looking_for': true},
      });
      expect(toggle(tester, 'looking_for').value, isTrue);
    });

    /// Сервер отказал — переключатель не должен врать, будто поле открыто.
    testWidgets('при ошибке переключатель остаётся как был', (tester) async {
      _tallWindow(tester);
      final h = _apiWithStub((o) {
        if (o.method == 'PATCH') {
          return (422, {'message': 'Сейчас изменить нельзя'});
        }
        return (200, {'data': null});
      });
      final auth = AuthController(api: h.api, tokens: _FakeStorage())
        ..resident = _resident(withProfile: true);

      await tester.pumpWidget(_wrap(auth: auth, api: h.api));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const Key('visibility-contacts')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(toggle(tester, 'contacts').value, isTrue);
      expect(find.text('Сейчас изменить нельзя'), findsOneWidget);
    });
  });

  group('Фото профиля', () {
    Future<void> openSheet(WidgetTester tester, {String? avatarUrl}) async {
      _tallWindow(tester);
      final api = _apiThatFails();
      final auth = AuthController(api: api, tokens: _FakeStorage())
        ..resident = _resident(avatarUrl: avatarUrl);

      await tester.pumpWidget(_wrap(auth: auth, api: api));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byType(DUserAvatar));
      await tester.pumpAndSettle();
    }

    testWidgets('своё фото можно открыть и рассмотреть', (tester) async {
      await openSheet(tester, avatarUrl: 'http://stub.test/storage/a.jpg');

      expect(find.text('Посмотреть фото'), findsOneWidget);
      expect(find.text('Выбрать другое'), findsOneWidget);
      expect(find.text('Удалить фото'), findsOneWidget);

      await tester.tap(find.text('Посмотреть фото'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PhotoViewScreen), findsOneWidget);
    });

    testWidgets('без фото смотреть и удалять нечего', (tester) async {
      await openSheet(tester);

      expect(find.text('Посмотреть фото'), findsNothing);
      expect(find.text('Удалить фото'), findsNothing);
      expect(find.text('Выбрать из галереи'), findsOneWidget);
    });
  });

  testWidgets('строка «Карта резидента» открывает экран карты', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Карта резидента'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ResidentCardScreen), findsOneWidget);
  });

  testWidgets('уведомления отключены — предлагается разрешить', (tester) async {
    _tallWindow(tester);
    _notifGranted = false;
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Разрешить напоминания'), findsOneWidget);
  });

  testWidgets('уведомления включены — видно, что напоминания стоят', (
    tester,
  ) async {
    _tallWindow(tester);
    _pendingReminders = const [
      {'id': 1001, 'title': 'Как прошла неделя?', 'body': '', 'payload': null},
    ];
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Напомним в пятницу утром и в воскресенье вечером'),
      findsOneWidget,
    );
    expect(find.text('Разрешить напоминания'), findsNothing);
  });

  testWidgets('чек-ин сделан — напоминания молчат осознанно', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Чек-ин за эту неделю сделан — напоминаний не будет'),
      findsOneWidget,
    );
  });

  testWidgets('выход требует подтверждения', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Выйти'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Чтобы вернуться, понадобятся логин и пароль.'),
      findsOneWidget,
    );

    // Отмена ничего не рушит: резидент остаётся в системе
    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.resident, isNotNull);

    // Подтверждение выходит даже при недоступном сервере —
    // иначе человек заперт в приложении с мёртвым токеном
    await tester.tap(find.text('Выйти'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Выйти').last);
    await tester.pump(const Duration(seconds: 1));

    expect(auth.stage, AuthStage.signedOut);
    expect(auth.resident, isNull);
  });

  testWidgets('смена пароля: отправка заблокирована, пока поля не заполнены', (
    tester,
  ) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Сменить пароль'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Смена пароля'), findsOneWidget);
    expect(find.text('Не короче 8 символов'), findsOneWidget);

    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сменить'),
    );
    expect(disabled.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'старый-пароль');
    await tester.enterText(find.byType(TextField).last, 'коротко');
    await tester.pump();

    final stillDisabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сменить'),
    );
    expect(stillDisabled.onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'новый-пароль-8');
    await tester.pump();

    final ready = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Сменить'),
    );
    expect(ready.onPressed, isNotNull);
  });

  testWidgets('версия приложения и адрес сервера видны', (tester) async {
    _tallWindow(tester);
    final api = _apiThatFails();
    final auth = AuthController(api: api, tokens: _FakeStorage())
      ..resident = _resident();

    await tester.pumpWidget(_wrap(auth: auth, api: api));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(ProfileScreen.appVersion), findsOneWidget);
    expect(find.text(ApiConfig.baseUrl), findsOneWidget);
  });

  group('Удаление аккаунта', () {
    testWidgets('в разделе «Аккаунт» есть пункт удаления', (tester) async {
      _tallWindow(tester);
      final h = _apiWithStub((o) => (200, {'data': null}));
      final auth = AuthController(api: h.api, tokens: _FakeStorage())
        ..resident = _resident();

      await tester.pumpWidget(_wrap(auth: auth, api: h.api));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Удалить аккаунт'), findsOneWidget);
    });

    testWidgets('подтверждение отправляет запрос и показывает состояние', (
      tester,
    ) async {
      _tallWindow(tester);
      var submitted = false;
      final h = _apiWithStub((o) {
        if (o.method == 'POST') {
          submitted = true;
          return (
            201,
            {
              'data': {
                'id': 1,
                'status': 'pending',
                'created_at': '2026-09-29T10:00:00+00:00',
              },
            },
          );
        }
        return (200, {'data': null});
      });
      final auth = AuthController(api: h.api, tokens: _FakeStorage())
        ..resident = _resident();

      await tester.pumpWidget(_wrap(auth: auth, api: h.api));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Удалить аккаунт'));
      await tester.pumpAndSettle();

      // Человек должен понимать, что именно произойдёт, до нажатия
      expect(find.textContaining('организатор'), findsWidgets);

      await tester.tap(find.text('Отправить запрос'));
      await tester.pumpAndSettle();

      expect(submitted, isTrue);
      expect(find.text('Запрос на удаление отправлен'), findsOneWidget);
      expect(find.text('Отменить запрос'), findsOneWidget);
    });

    testWidgets('поданный запрос виден при открытии и отзывается', (
      tester,
    ) async {
      _tallWindow(tester);
      var cancelled = false;
      final h = _apiWithStub((o) {
        if (o.method == 'DELETE') {
          cancelled = true;
          return (200, {'data': null});
        }
        if (cancelled) return (200, {'data': null});
        return (
          200,
          {
            'data': {
              'id': 7,
              'status': 'pending',
              'created_at': '2026-09-29T10:00:00+00:00',
            },
          },
        );
      });
      final auth = AuthController(api: h.api, tokens: _FakeStorage())
        ..resident = _resident();

      await tester.pumpWidget(_wrap(auth: auth, api: h.api));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Запрос на удаление отправлен'), findsOneWidget);

      await tester.tap(find.text('Отменить запрос'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(find.text('Удалить аккаунт'), findsOneWidget);
    });
  });
}
