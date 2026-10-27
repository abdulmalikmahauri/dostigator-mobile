import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'push_channel.dart';

PushChannel createPushChannel() => const _BrowserPush();

/// Уведомления через сам браузер (Web Push).
///
/// На айфоне это работает с iOS 16.4 и только из приложения,
/// поставленного на экран «Домой»: во вкладке Safari нужных объектов
/// в браузере просто нет.
class _BrowserPush implements PushChannel {
  const _BrowserPush();

  /// Сколько ждём фоновый обработчик. Если он не зарегистрировался
  /// (приватное окно), браузер не ответит никогда — без предела ожидания
  /// кнопка «Включить» крутилась бы вечно.
  static const _workerTimeout = Duration(seconds: 10);

  bool get _supported =>
      globalContext.has('Notification') &&
      globalContext.has('PushManager') &&
      web.window.navigator.has('serviceWorker');

  /// Айфон или айпад. Айпад с некоторых версий представляется компьютером
  /// Mac — его выдаёт сенсорный экран.
  bool get _isAppleMobile {
    final agent = web.window.navigator.userAgent;

    return agent.contains('iPhone') ||
        agent.contains('iPad') ||
        (agent.contains('Macintosh') &&
            web.window.navigator.maxTouchPoints > 1);
  }

  /// Открыто с иконки на экране «Домой», а не во вкладке браузера.
  bool get _isInstalled =>
      web.window.matchMedia('(display-mode: standalone)').matches;

  @override
  Future<PushState> state() => _guarded(() async {
    if (!_supported) {
      return _isAppleMobile && !_isInstalled
          ? PushState.needsInstall
          : PushState.unsupported;
    }

    return switch (web.Notification.permission) {
      'granted' => PushState.granted,
      'denied' => PushState.denied,
      _ => PushState.prompt,
    };
  });

  @override
  Future<PushSubscriptionData?> subscribe(String serverKey) {
    if (!_supported) return Future.value();

    // Первым делом — вопрос о разрешении, без единой паузы до него:
    // иначе айфон сочтёт, что человек ничего не нажимал, и промолчит.
    // Поэтому вызов стоит до любых await, вне защитной обёртки.
    final JSPromise<JSString> asked;
    try {
      asked = web.Notification.requestPermission();
    } on Object catch (e) {
      // Граница с JavaScript: браузер бросает свои ошибки, не наши
      throw PushException('Браузер не дал спросить разрешение: $e');
    }

    return _guarded(() async {
      final permission = await asked.toDart;

      if (permission.toDart != 'granted') return null;

      final registration = await _worker();
      final subscription = await registration.pushManager
          .subscribe(
            web.PushSubscriptionOptionsInit(
              // Браузеры требуют показывать каждое пришедшее уведомление
              userVisibleOnly: true,
              applicationServerKey: _decodeKey(serverKey).toJS,
            ),
          )
          .toDart;

      return _read(subscription);
    });
  }

  @override
  Future<PushSubscriptionData?> subscription() => _guarded(() async {
    final existing = await _existing();

    return existing == null ? null : _read(existing);
  });

  @override
  Future<void> unsubscribe() => _guarded(() async {
    final existing = await _existing();

    if (existing != null) await existing.unsubscribe().toDart;
  });

  Future<web.PushSubscription?> _existing() async {
    if (!_supported) return null;

    final registration = await _worker();

    return registration.pushManager.getSubscription().toDart;
  }

  Future<web.ServiceWorkerRegistration> _worker() {
    return web.window.navigator.serviceWorker.ready.toDart.timeout(
      _workerTimeout,
    );
  }

  PushSubscriptionData? _read(web.PushSubscription subscription) {
    final json = subscription.toJSON();
    final keys = json.keys;

    final p256dh = (keys['p256dh'] as JSString?)?.toDart;
    final auth = (keys['auth'] as JSString?)?.toDart;

    if (p256dh == null || auth == null) return null;

    return PushSubscriptionData(
      endpoint: json.endpoint,
      p256dh: p256dh,
      auth: auth,
    );
  }

  /// Ключ сервера приходит строкой в «интернет-варианте» base64;
  /// браузеру нужны сами байты.
  static Uint8List _decodeKey(String key) =>
      base64Url.decode(base64Url.normalize(key));

  /// Всё, что может пойти не так в браузере, превращаем в [PushException].
  ///
  /// Ловим `Object`, а не `Exception`: ошибки браузера приходят объектами
  /// JavaScript и исключениями Dart не являются. Без этого сбой улетал бы
  /// мимо всех обработчиков, а кнопка молча возвращалась на место.
  static Future<T> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PushException {
      rethrow;
    } on TimeoutException {
      throw const PushException('Браузер не ответил вовремя');
    } on Object catch (e) {
      throw PushException('Браузер не справился с уведомлениями: $e');
    }
  }
}
