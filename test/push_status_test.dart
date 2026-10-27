import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/push/push_channel.dart';
import 'package:dostigator/core/push/push_service.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/widgets/d_push_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/api.dart';
import 'helpers/notifications.dart';

/// Браузер, который ведёт себя так, как велел тест.
class _FakeBrowser implements PushChannel {
  _FakeBrowser(this.current);

  PushState current;

  /// Что браузер ответит на просьбу о разрешении: подписка или отказ.
  PushSubscriptionData? grants = const PushSubscriptionData(
    endpoint: 'https://push.example/abc',
    p256dh: 'browser-key',
    auth: 'browser-secret',
  );

  PushSubscriptionData? existing;

  /// Браузер сломался при подписке: так бывает в приватном окне.
  bool breaks = false;

  bool unsubscribed = false;

  final askedWithKeys = <String>[];

  @override
  Future<PushState> state() async => current;

  @override
  Future<PushSubscriptionData?> subscribe(String serverKey) async {
    askedWithKeys.add(serverKey);

    if (breaks) throw const PushException('Браузер не оформил подписку');

    current = grants == null ? PushState.denied : PushState.granted;

    return grants;
  }

  @override
  Future<PushSubscriptionData?> subscription() async => existing;

  @override
  Future<void> unsubscribe() async {
    unsubscribed = true;
    existing = null;
  }
}

/// Браузер, в котором уведомления сломаны целиком.
class _BrokenBrowser implements PushChannel {
  @override
  Future<PushState> state() async =>
      throw const PushException('Браузер не отвечает');

  @override
  Future<PushSubscriptionData?> subscribe(String serverKey) async =>
      throw const PushException('Браузер не отвечает');

  @override
  Future<PushSubscriptionData?> subscription() async =>
      throw const PushException('Браузер не отвечает');

  @override
  Future<void> unsubscribe() async =>
      throw const PushException('Браузер не отвечает');
}

({ApiClient api, PushService service, StubAdapter stub}) _service(
  _FakeBrowser browser, {
  bool Function()? keyAvailable,
}) {
  final h = stubbedApi((call) {
    if (call.path == '/push/key') {
      if (!(keyAvailable?.call() ?? true)) {
        return (422, {'message': 'Нет связи с сервером'});
      }

      return (
        200,
        {
          'data': {'public_key': 'SERVER-KEY'},
        },
      );
    }
    return (201, {'data': null});
  });

  return (
    api: h.api,
    service: PushService(api: h.api, channel: browser),
    stub: h.stub,
  );
}

Future<void> _pump(WidgetTester tester, PushService service) async {
  await tester.pumpWidget(
    Provider<PushService?>.value(
      value: service,
      child: MaterialApp(
        theme: buildDostigatorTheme(),
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(24), child: DPushStatus()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // Выход из аккаунта снимает и напоминания телефона — им нужна заглушка
  setUpAll(silenceNotifications);

  /// На айфоне уведомления работают только из приложения, поставленного
  /// на экран «Домой». В обычной вкладке Safari кнопка была бы обманом.
  testWidgets('в Safari на айфоне объясняем, как поставить на экран «Домой»', (
    tester,
  ) async {
    final h = _service(_FakeBrowser(PushState.needsInstall));

    await _pump(tester, h.service);

    expect(find.textContaining('На экран «Домой»'), findsOneWidget);
    expect(find.text('Включить уведомления'), findsNothing);
  });

  testWidgets('пока не спрашивали — предлагаем включить', (tester) async {
    final h = _service(_FakeBrowser(PushState.prompt));

    await _pump(tester, h.service);

    expect(find.text('Включить уведомления'), findsOneWidget);
  });

  /// Айфон показывает вопрос о разрешении только сразу после нажатия.
  /// Сходить за ключом на сервер в этот момент уже нельзя — берём заранее.
  testWidgets('ключ сервера запрашивается заранее, до нажатия', (tester) async {
    final h = _service(_FakeBrowser(PushState.prompt));

    await _pump(tester, h.service);

    expect(h.stub.calls.map((c) => c.toString()), ['GET /push/key']);
  });

  testWidgets('включение подписывает браузер и сообщает серверу', (
    tester,
  ) async {
    final browser = _FakeBrowser(PushState.prompt);
    final h = _service(browser);

    await _pump(tester, h.service);

    await tester.tap(find.text('Включить уведомления'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(browser.askedWithKeys, ['SERVER-KEY']);

    final sent = h.stub.calls.last;
    expect(sent.toString(), 'POST /push/subscription');
    expect(sent.body, {
      'endpoint': 'https://push.example/abc',
      'keys': {'p256dh': 'browser-key', 'auth': 'browser-secret'},
    });

    expect(find.textContaining('Уведомления включены'), findsOneWidget);
    expect(find.text('Включить уведомления'), findsNothing);
  });

  /// Айфон не покажет вопрос о разрешении, если между нажатием и вопросом
  /// была пауза на поход за ключом. Поэтому без ключа кнопки «Включить»
  /// нет вовсе — сначала «Повторить», пока ключ не получен.
  testWidgets('без ключа сервера включить нельзя — сначала «Повторить»', (
    tester,
  ) async {
    var online = false;
    final browser = _FakeBrowser(PushState.prompt);
    final h = _service(browser, keyAvailable: () => online);

    await _pump(tester, h.service);

    expect(find.text('Включить уведомления'), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);

    online = true;
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Включить уведомления'), findsOneWidget);
    // Сам вопрос о разрешении ещё не задавался
    expect(browser.askedWithKeys, isEmpty);
  });

  /// Раньше в этом случае кнопка молча возвращалась на место.
  testWidgets('сбой браузера при подписке виден человеку', (tester) async {
    final browser = _FakeBrowser(PushState.prompt)..breaks = true;
    final h = _service(browser);

    await _pump(tester, h.service);

    await tester.tap(find.text('Включить уведомления'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Не удалось включить'), findsOneWidget);
    // Кнопка снова доступна, а не крутит вечный спиннер
    expect(find.text('Включить уведомления'), findsOneWidget);
    expect(h.stub.calls.where((c) => c.path == '/push/subscription'), isEmpty);
  });

  testWidgets('человек отказал — на сервер ничего не уходит', (tester) async {
    final browser = _FakeBrowser(PushState.prompt)..grants = null;
    final h = _service(browser);

    await _pump(tester, h.service);

    await tester.tap(find.text('Включить уведомления'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(h.stub.calls.where((c) => c.path == '/push/subscription'), isEmpty);
    expect(find.textContaining('запрещены'), findsOneWidget);
  });

  testWidgets('запрещено в настройках — говорим, где разрешить', (
    tester,
  ) async {
    final h = _service(_FakeBrowser(PushState.denied));

    await _pump(tester, h.service);

    expect(find.textContaining('запрещены'), findsOneWidget);
    expect(find.text('Включить уведомления'), findsNothing);
  });

  testWidgets('браузер не умеет уведомления — так и говорим', (tester) async {
    final h = _service(_FakeBrowser(PushState.unsupported));

    await _pump(tester, h.service);

    expect(find.textContaining('не умеет'), findsOneWidget);
    expect(find.text('Включить уведомления'), findsNothing);
  });

  group('После входа', () {
    /// Подписка привязана к тому, кто вошёл последним. Сменился человек
    /// в этом браузере — уведомления должны уйти уже ему.
    test('действующая подписка привязывается к вошедшему', () async {
      final browser = _FakeBrowser(PushState.granted)
        ..existing = const PushSubscriptionData(
          endpoint: 'https://push.example/abc',
          p256dh: 'browser-key',
          auth: 'browser-secret',
        );
      final h = _service(browser);

      await h.service.syncIfGranted();

      expect(h.stub.calls.single.toString(), 'POST /push/subscription');
    });

    test('без разрешения сервер не трогаем', () async {
      final h = _service(_FakeBrowser(PushState.prompt));

      await h.service.syncIfGranted();

      expect(h.stub.calls, isEmpty);
    });

    /// Привязка идёт в фоне при каждом открытии: сбой браузера
    /// не должен превращаться в ошибку приложения.
    test('сбой браузера при привязке проходит молча', () async {
      final browser = _BrokenBrowser();
      final h = stubbedApi((call) => (201, {'data': null}));
      final service = PushService(api: h.api, channel: browser);

      await service.syncIfGranted();

      expect(h.stub.calls, isEmpty);
    });
  });

  group('При выходе', () {
    const subscription = PushSubscriptionData(
      endpoint: 'https://push.example/abc',
      p256dh: 'browser-key',
      auth: 'browser-secret',
    );

    /// На общем компьютере уведомления ушедшего человека — с названием
    /// его цели и словом «взнос» — не должны продолжать приходить.
    test('браузер отписывается и на сервере, и у себя', () async {
      final browser = _FakeBrowser(PushState.granted)..existing = subscription;
      final h = _service(browser);

      await h.service.unsubscribe();

      final call = h.stub.calls.single;
      expect(call.toString(), 'DELETE /push/subscription');
      expect(call.body, {'endpoint': 'https://push.example/abc'});
      expect(browser.unsubscribed, isTrue);
    });

    test('подписки нет — и отписывать нечего', () async {
      final browser = _FakeBrowser(PushState.prompt);
      final h = _service(browser);

      await h.service.unsubscribe();

      expect(h.stub.calls, isEmpty);
    });

    /// Отписка идёт до выхода: после него сервер уже не узнает человека.
    test('выход из аккаунта сначала отписывает браузер', () async {
      final browser = _FakeBrowser(PushState.granted)..existing = subscription;
      final h = _service(browser);
      final auth = AuthController(
        api: h.api,
        tokens: MemoryTokenStorage(),
        push: h.service,
      );

      await auth.signOut();

      expect(h.stub.calls.map((c) => c.toString()), [
        'DELETE /push/subscription',
        'POST /auth/logout',
      ]);
      expect(browser.unsubscribed, isTrue);
    });
  });
}
