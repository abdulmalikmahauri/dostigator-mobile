import 'push_channel_stub.dart'
    if (dart.library.js_interop) 'push_channel_web.dart'
    as platform;

/// Что сейчас с уведомлениями от сервера в этом браузере.
enum PushState {
  /// Браузер не умеет уведомления вовсе.
  unsupported,

  /// Айфон, сайт открыт во вкладке Safari. Уведомления заработают только
  /// после того, как приложение поставят на экран «Домой».
  needsInstall,

  /// Разрешение ещё не спрашивали.
  prompt,

  granted,

  /// Человек отказал или запретил в настройках. Спросить повторно
  /// браузер не даст — разрешить можно только в его настройках.
  denied,
}

/// Браузер не справился с уведомлениями: приватное окно, служба браузера
/// недоступна, фоновый обработчик не запустился. Причин много, человеку
/// из них важно одно — «не получилось».
class PushException implements Exception {
  const PushException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Подписка браузера: адрес службы доставки и ключи шифрования.
/// Сервер по ним присылает уведомление именно в этот браузер.
class PushSubscriptionData {
  const PushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'keys': {'p256dh': p256dh, 'auth': auth},
  };
}

/// Разговор с браузером об уведомлениях. Отдельный интерфейс нужен,
/// чтобы экран можно было проверить без настоящего браузера.
///
/// Любой сбой браузера реализация обязана отдать как [PushException].
abstract interface class PushChannel {
  /// Текущее состояние — без вопросов к человеку.
  Future<PushState> state();

  /// Спрашивает разрешение и оформляет подписку.
  ///
  /// Вызывать только прямо из обработчика нажатия: айфон показывает
  /// вопрос о разрешении лишь в ответ на действие человека. Поэтому
  /// [serverKey] должен быть получен заранее.
  ///
  /// Возвращает null, если человек отказал.
  Future<PushSubscriptionData?> subscribe(String serverKey);

  /// Уже оформленная подписка, если она есть.
  Future<PushSubscriptionData?> subscription();

  /// Снимает подписку в самом браузере.
  Future<void> unsubscribe();
}

/// Канал для текущей платформы: настоящий — в браузере,
/// «не умеет» — в приложении на телефоне (там свои напоминания).
PushChannel createPushChannel() => platform.createPushChannel();
