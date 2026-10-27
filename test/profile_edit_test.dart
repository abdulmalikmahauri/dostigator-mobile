import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/resident.dart';
import 'package:dostigator/screens/profile_edit_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/api.dart';

Map<String, dynamic> _me({String name = 'Адам Глебов', String? city}) {
  return {
    'id': 1,
    'name': name,
    'phone': '+79000001122',
    'phone_pretty': '+7 900 000-11-22',
    'city': city ?? 'Грозный',
    'telegram': '@adam',
    'whatsapp': '+79000001122',
    'card_number': 'DG-00001',
    'tier_label': 'Бизнес-клуб',
    'is_club_member': true,
    'memberships': const [],
    'profile': {
      'business_name': 'Клиника Адама',
      'niche': 'Медицина',
      'description': 'Три клиники в Грозном',
      'can_help': 'Помогу с медициной',
      'looking_for': 'Ищу управляющего',
      'website': 'https://adam.example',
      'instagram': 'adam.clinic',
      'employees_count': 40,
      'visibility': const {},
    },
  };
}

AuthController _auth(ApiClient api) {
  return AuthController(api: api, tokens: MemoryTokenStorage())
    ..resident = Resident.fromJson(_me());
}

Future<void> _pump(WidgetTester tester, AuthController auth) async {
  // Форма длиннее окна теста, а ListView строит только видимое
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp(
        theme: buildDostigatorTheme(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ProfileEditScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('форма открывается с нынешними данными', (tester) async {
    await _pump(tester, _auth(unreachableApi()));

    expect(find.text('Адам Глебов'), findsOneWidget);
    expect(find.text('Грозный'), findsOneWidget);
    expect(find.text('@adam'), findsOneWidget);
    expect(find.text('Клиника Адама'), findsOneWidget);
    expect(find.text('Медицина'), findsOneWidget);
    expect(find.text('Помогу с медициной'), findsOneWidget);
    expect(find.text('Ищу управляющего'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });

  /// Телефон — это логин. Поменять его из приложения нельзя, и экран
  /// говорит об этом прямо, а не прячет поле молча.
  testWidgets('телефон для входа показан, но не правится', (tester) async {
    await _pump(tester, _auth(unreachableApi()));

    expect(find.byKey(const Key('profile-phone')), findsNothing);
    expect(find.textContaining('+7 900 000-11-22'), findsOneWidget);
    expect(find.textContaining('меняет организатор'), findsOneWidget);
  });

  testWidgets('сохранение отправляет данные и обновляет профиль', (
    tester,
  ) async {
    final h = stubbedApi(
      (call) =>
          (200, {'data': _me(name: 'Адам Глебов-младший', city: 'Аргун')}),
    );
    final auth = _auth(h.api);

    await _pump(tester, auth);

    await tester.enterText(
      find.byKey(const Key('profile-name')),
      'Адам Глебов-младший',
    );
    await tester.enterText(find.byKey(const Key('profile-city')), 'Аргун');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final call = h.stub.calls.single;

    expect(call.toString(), 'PATCH /me');
    expect(call.body?['name'], 'Адам Глебов-младший');
    expect(call.body?['city'], 'Аргун');
    expect(call.body?['business_name'], 'Клиника Адама');
    expect(call.body?['employees_count'], 40);
    // Телефон, роль и доступ в запрос не попадают вовсе
    expect(call.body?.containsKey('phone'), isFalse);

    expect(auth.resident?.name, 'Адам Глебов-младший');
  });

  testWidgets('стёртое поле уходит на сервер пустым, а не прежним', (
    tester,
  ) async {
    final h = stubbedApi((call) => (200, {'data': _me()}));

    await _pump(tester, _auth(h.api));

    await tester.enterText(find.byKey(const Key('profile-telegram')), '');
    await tester.enterText(find.byKey(const Key('profile-employees')), '');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final body = h.stub.calls.single.body;

    expect(body?.containsKey('telegram'), isTrue);
    expect(body?['telegram'], isNull);
    expect(body?['employees_count'], isNull);
  });

  testWidgets('без имени форма не отправляется', (tester) async {
    final h = stubbedApi((call) => (200, {'data': _me()}));

    await _pump(tester, _auth(h.api));

    await tester.enterText(find.byKey(const Key('profile-name')), '  ');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(find.text('Укажите имя'), findsOneWidget);
    expect(h.stub.calls, isEmpty);
  });

  /// Сервер отклонил правку — введённое не теряется.
  testWidgets('ошибка сервера видна, данные остаются в форме', (tester) async {
    final h = stubbedApi(
      (call) => (
        422,
        {
          'message': 'Не похоже на номер телефона',
          'errors': {
            'whatsapp': ['Не похоже на номер телефона'],
          },
        },
      ),
    );

    await _pump(tester, _auth(h.api));

    await tester.enterText(find.byKey(const Key('profile-whatsapp')), 'пишите');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Не похоже на номер телефона'), findsOneWidget);
    expect(find.text('пишите'), findsOneWidget);
  });

  /// Кнопка стоит последней строкой формы — как в форме цели.
  testWidgets('кнопка сохранения — в самом низу формы', (tester) async {
    await _pump(tester, _auth(unreachableApi()));

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Сохранить'),
      ),
      findsOneWidget,
    );
  });
}
