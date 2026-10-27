import '../api_client.dart';
import 'push_channel.dart';

/// Уведомления от сервера в браузере: соединяет браузер и наш сервер.
///
/// Браузер выдаёт подписку, сервер по ней шлёт напоминания о чек-ине
/// и взносе. Приложению на телефоне это не нужно — оно напоминает само.
class PushService {
  // ignore: prefer_initializing_formals — приватные имена у именованных
  // параметров запрещены, поэтому this._api здесь недоступен.
  PushService({required ApiClient api, required PushChannel channel})
    : _api = api,
      _channel = channel;

  final ApiClient _api;
  final PushChannel _channel;

  /// Ключ сервера, которым браузер помечает подписку как «нашу».
  String? _serverKey;

  /// Ключ уже получен — можно включать по нажатию.
  ///
  /// Айфон показывает вопрос о разрешении только сразу после нажатия.
  /// Поход за ключом в этот момент — уже пауза, и вопрос не появится
  /// вовсе, причём молча. Поэтому без ключа кнопку «Включить» экран
  /// не показывает.
  bool get isReady => _serverKey != null;

  Future<PushState> state() => _channel.state();

  /// Заранее получает ключ сервера. Возвращает, удалось ли.
  Future<bool> prepare() async {
    if (isReady) return true;

    try {
      final response = await _api.get('/push/key');
      final data = response['data'];
      final key = data is Map<String, dynamic> ? data['public_key'] : null;

      if (key is String && key.isNotEmpty) _serverKey = key;
    } on ApiException {
      // Нет связи — экран предложит повторить
    }

    return isReady;
  }

  /// Включает уведомления. Вызывать из обработчика нажатия и только
  /// когда [isReady]: до вопроса о разрешении не должно быть ни одной паузы.
  ///
  /// Возвращает новое состояние. Бросает [PushException], если не справился
  /// браузер, и [ApiException], если подписку не принял сервер.
  Future<PushState> enable() async {
    final key = _serverKey;

    if (key == null) {
      throw const PushException('Ключ сервера ещё не получен');
    }

    final subscription = await _channel.subscribe(key);

    if (subscription == null) return _channel.state();

    await _api.post('/push/subscription', subscription.toJson());

    return PushState.granted;
  }

  /// После входа: если уведомления уже разрешены, привязывает подписку
  /// этого браузера к вошедшему человеку. Иначе они продолжали бы
  /// приходить тому, кто входил здесь раньше.
  ///
  /// Работает в фоне и молча: ни вопросов человеку, ни ошибок на экран.
  Future<void> syncIfGranted() async {
    try {
      if (await _channel.state() != PushState.granted) return;

      final subscription = await _channel.subscription();
      if (subscription == null) return;

      await _api.post('/push/subscription', subscription.toJson());
    } on ApiException {
      // Попробуем при следующем входе
    } on PushException {
      // Браузер не ответил — уведомления просто останутся как были
    }
  }

  /// При выходе из аккаунта: снимает подписку и на сервере, и в браузере.
  ///
  /// Без этого на общем компьютере уведомления ушедшего человека —
  /// с названием его цели и напоминанием о взносе — приходили бы дальше.
  /// Вызывать до самого выхода: после него сервер человека уже не узнает.
  /// Молча: выйти человек должен в любом случае.
  Future<void> unsubscribe() async {
    try {
      final subscription = await _channel.subscription();
      if (subscription == null) return;

      try {
        await _api.delete('/push/subscription', {
          'endpoint': subscription.endpoint,
        });
      } on ApiException {
        // Сервер недоступен — подписку в браузере всё равно снимаем
      }

      await _channel.unsubscribe();
    } on PushException {
      // Браузер не ответил — мешать выходу это не должно
    }
  }
}
