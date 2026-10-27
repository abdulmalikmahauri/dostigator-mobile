import 'push_channel.dart';

PushChannel createPushChannel() => const _NoPush();

/// Не браузер: уведомления от сервера здесь не приходят.
/// Приложение на телефоне напоминает само — см. `Reminders`.
class _NoPush implements PushChannel {
  const _NoPush();

  @override
  Future<PushState> state() async => PushState.unsupported;

  @override
  Future<PushSubscriptionData?> subscribe(String serverKey) async => null;

  @override
  Future<PushSubscriptionData?> subscription() async => null;

  @override
  Future<void> unsubscribe() async {}
}
