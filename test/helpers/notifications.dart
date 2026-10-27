import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Служба уведомлений телефона для тестов, которым она не важна, но
/// мимо которой не пройти: выход из аккаунта, например, снимает
/// напоминания. Без заглушки плагин падает — в тестах его некому
/// зарегистрировать.
///
/// Отвечает «уведомления выключены» и ничего не планирует.
void silenceNotifications() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => switch (call.method) {
          'initialize' => true,
          'areNotificationsEnabled' => false,
          'pendingNotificationRequests' => const <Object?>[],
          _ => null,
        },
      );
}
