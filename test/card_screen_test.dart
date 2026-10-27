import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/resident.dart';
import 'package:dostigator/screens/card_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/widgets/d_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:dostigator/widgets/d_qr_card.dart';

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

/// Фейковый API: отдаёт заранее подготовленные ответы /me/card по очереди.
/// Так проверяется главное — что после истечения срока экран получает
/// и показывает НОВЫЙ токен, а не кэширует старый.
class _FakeCardApi extends ApiClient {
  _FakeCardApi({this.responses = const [], this.failFirst = 0})
    : super(
        tokens: _FakeStorage(),
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')),
      );

  final List<Map<String, dynamic>> responses;

  /// Сколько первых запросов уронить — для проверки retry.
  int failFirst;

  int calls = 0;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls++;
    if (failFirst > 0) {
      failFirst--;
      throw ApiException('Не удалось загрузить карту');
    }
    if (responses.isEmpty) {
      throw ApiException('Не удалось загрузить карту');
    }
    final index = (calls - 1).clamp(0, responses.length - 1);
    return responses[index];
  }
}

Resident _resident({String? paidUntil = '2026-12-31'}) {
  return Resident.fromJson({
    'id': 1,
    'name': 'Али-Бек Мусаев',
    'phone': '+79000000001',
    'card_number': 'DG-00001',
    'tier_label': 'Бизнес-клуб',
    'is_club_member': true,
    'memberships': [
      {
        'tier': 'club',
        'tier_label': 'Бизнес-клуб',
        'status_label': 'Действует',
        'is_overdue': false,
        if (paidUntil != null) 'paid_until': paidUntil,
      },
    ],
  });
}

Widget _wrap(ApiClient api, {Resident? resident}) {
  return MultiProvider(
    providers: [
      themeProvider(),
      directoryProvider(),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: api, tokens: _FakeStorage())
          ..resident = resident,
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
      home: const ResidentCardScreen(),
    ),
  );
}

/// Экран держит Timer.periodic — перед концом теста дерево надо снести,
/// иначе flutter_test падает на «pending timer».
Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  testWidgets('пока карта грузится — скелет, не спиннер на весь экран', (
    tester,
  ) async {
    final api = _FakeCardApi(
      responses: [
        {'qr_token': 'token-1', 'expires_in': 60},
      ],
    );

    await tester.pumpWidget(_wrap(api, resident: _resident()));

    // Первый кадр: запрос ещё в полёте
    expect(find.byType(DSkeletonCard), findsOneWidget);
    expect(find.byType(DQrCard), findsNothing);

    await _tearDownTree(tester);
  });

  testWidgets('цифровая карта показывает имя, уровень, номер и срок', (
    tester,
  ) async {
    final api = _FakeCardApi(
      responses: [
        {'qr_token': 'token-1', 'expires_in': 60},
      ],
    );

    await tester.pumpWidget(_wrap(api, resident: _resident()));
    await tester.pump();

    expect(find.text('Карта резидента'), findsOneWidget);
    expect(find.text('Али-Бек Мусаев'), findsOneWidget);
    expect(find.text('Бизнес-клуб'), findsOneWidget);
    expect(find.text('DG-00001'), findsOneWidget);
    expect(find.text('ДЕЙСТВУЕТ ДО'), findsOneWidget);
    expect(find.text('31 декабря 2026'), findsOneWidget);
    expect(find.text('QR обновляется автоматически'), findsOneWidget);
    expect(find.byType(DQrCard), findsOneWidget);

    await _tearDownTree(tester);
  });

  testWidgets('без даты оплаты блок «Действует до» не показывается', (
    tester,
  ) async {
    final api = _FakeCardApi(
      responses: [
        {'qr_token': 'token-1', 'expires_in': 60},
      ],
    );

    await tester.pumpWidget(_wrap(api, resident: _resident(paidUntil: null)));
    await tester.pump();

    expect(find.text('ДЕЙСТВУЕТ ДО'), findsNothing);
    // Карта при этом на месте
    expect(find.text('DG-00001'), findsOneWidget);

    await _tearDownTree(tester);
  });

  /// Главный сценарий раздела 42: QR ротируется сам, без ручного refresh,
  /// и после ротации на экране именно новый токен.
  testWidgets('QR обновляется после истечения срока токена', (tester) async {
    final api = _FakeCardApi(
      responses: [
        {'qr_token': 'token-1', 'expires_in': 2},
        {'qr_token': 'token-2', 'expires_in': 2},
      ],
    );

    await tester.pumpWidget(_wrap(api, resident: _resident()));
    await tester.pump();

    expect(tester.widget<DQrCard>(find.byType(DQrCard)).data, 'token-1');

    // 1-я секунда — счётчик уменьшился, 2-я — сработала ротация
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(api.calls, 2);
    expect(tester.widget<DQrCard>(find.byType(DQrCard)).data, 'token-2');

    await _tearDownTree(tester);
  });

  testWidgets('ошибка загрузки: сообщение, «Повторить» и никакого старого QR', (
    tester,
  ) async {
    final api = _FakeCardApi(
      failFirst: 1,
      responses: [
        {'qr_token': 'token-1', 'expires_in': 60},
      ],
    );

    await tester.pumpWidget(_wrap(api, resident: _resident()));
    await tester.pump();

    expect(find.byType(DErrorState), findsOneWidget);
    expect(find.text('Не удалось загрузить карту'), findsOneWidget);
    // Токена не было и нет — просроченный/пустой QR не рисуем
    expect(find.byType(DQrCard), findsNothing);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(DErrorState), findsNothing);
    expect(tester.widget<DQrCard>(find.byType(DQrCard)).data, 'token-1');

    await _tearDownTree(tester);
  });

  /// Security-требование раздела 23: если ротация не удалась,
  /// просроченный токен обязан исчезнуть с экрана.
  testWidgets('после неудачной ротации старый QR не остаётся на экране', (
    tester,
  ) async {
    final api = _FakeCardApi(
      responses: [
        {'qr_token': 'token-1', 'expires_in': 2},
      ],
    );

    await tester.pumpWidget(_wrap(api, resident: _resident()));
    await tester.pump();
    expect(find.byType(DQrCard), findsOneWidget);

    // Второй запрос (ротация) падает
    api.failFirst = 1;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(DQrCard), findsNothing);
    expect(find.byType(DErrorState), findsOneWidget);

    await _tearDownTree(tester);
  });
}
