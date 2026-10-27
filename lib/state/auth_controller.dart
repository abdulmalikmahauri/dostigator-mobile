import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/push/push_service.dart';
import '../core/reminders.dart';
import '../core/token_storage.dart';
import '../models/resident.dart';

enum AuthStage { loading, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  // ignore: prefer_initializing_formals — Dart запрещает приватные имена
  // у именованных параметров, поэтому this._api здесь недоступен.
  AuthController({
    required ApiClient api,
    required TokenStorage tokens,
    PushService? push,
  }) : _api = api,
       _tokens = tokens,
       _push = push {
    _api.onUnauthorized = _handleTokenRejected;
  }

  final ApiClient _api;
  final TokenStorage _tokens;

  /// Уведомления браузера. Есть только в веб-версии.
  final PushService? _push;

  AuthStage stage = AuthStage.loading;
  Resident? resident;

  String? error;
  bool busy = false;

  Future<void> restoreSession() async {
    final token = await _tokens.read();

    if (token == null) {
      _set(stage: AuthStage.signedOut);
      return;
    }

    try {
      final response = await _api.get('/me');
      resident = Resident.fromJson(response['data'] as Map<String, dynamic>);
      _set(stage: AuthStage.signedIn);
      _syncFeeReminder();
    } on ApiException catch (e) {
      // Токен мог быть отозван, пока приложение не запускали.
      // Сетевой сбой — не повод выкидывать: пусть попробует войти снова.
      if (e.isUnauthorized) {
        await _tokens.clear();
      }
      _set(
        stage: AuthStage.signedOut,
        error: e.isUnauthorized ? null : e.message,
      );
    }
  }

  /// Вход по логину и паролю.
  ///
  /// Логин — номер телефона; если организатор завёл почту, подойдёт и она.
  /// Пароль выдаёт организатор: самостоятельного восстановления нет,
  /// потому что без SMS и почты подтвердить личность нечем.
  Future<bool> signIn(String login, String password) async {
    _set(busy: true, error: null);

    try {
      final response = await _api.post('/auth/login', {
        'login': login.trim(),
        'password': password,
        'device_name': _deviceName,
      });

      await _tokens.write(response['token'] as String);

      // Внимание на форму ответа: в /auth/login пользователь лежит плоско
      // внутри ключа user, а в /me — обёрнут в data. Так работает Laravel:
      // обёртка добавляется, только когда ресурс сам является ответом.
      resident = Resident.fromJson(response['user'] as Map<String, dynamic>);

      _set(stage: AuthStage.signedIn, busy: false);
      _syncFeeReminder();
      return true;
    } on ApiException catch (e) {
      _set(busy: false, error: e.message);
      return false;
    }
  }

  /// Смена своего пароля. Прочие устройства сервер разлогинивает сам.
  Future<String?> changePassword(String current, String next) async {
    _set(busy: true, error: null);

    try {
      await _api.post('/auth/password', {
        'current_password': current,
        'password': next,
        'password_confirmation': next,
      });
      _set(busy: false);

      return null;
    } on ApiException catch (e) {
      _set(busy: false);

      return e.message;
    }
  }

  /// Правка своих данных и переключателей приватности.
  ///
  /// Сервер отвечает профилем целиком — подставляем его сразу, без
  /// отдельного запроса. Возвращает текст ошибки либо null при успехе.
  Future<String?> updateProfile(Map<String, dynamic> changes) async {
    try {
      final response = await _api.patch('/me', changes);
      resident = Resident.fromJson(response['data'] as Map<String, dynamic>);
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> refreshResident() async {
    try {
      final response = await _api.get('/me');
      resident = Resident.fromJson(response['data'] as Map<String, dynamic>);
      notifyListeners();
      _syncFeeReminder();
    } on ApiException {
      // Молча: обновление профиля не должно рушить экран, который уже показан
    }
  }

  Future<void> signOut() async {
    // Сначала отписываем браузер: после выхода сервер человека уже
    // не узнает, и его уведомления остались бы приходить сюда
    await _push?.unsubscribe();

    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Даже если сервер недоступен, локально выходим — иначе человек
      // останется заперт в приложении с недействующим токеном
    }

    await _tokens.clear();
    resident = null;
    _set(stage: AuthStage.signedOut);

    // Чужие напоминания на этом телефоне не нужны
    await Reminders.cancelEverything();
  }

  /// Напоминания о взносе ставит само приложение — по дням, которые
  /// назвал сервер. Сверяем при каждом свежем профиле: оплатил —
  /// напоминания снимаются.
  ///
  /// В фоне: вход и показ профиля не должны ждать службу уведомлений.
  void _syncFeeReminder() {
    unawaited(Reminders.syncFee(resident?.feeReminder));
  }

  /// Как это устройство назовётся в списке входов на сервере.
  static String get _deviceName {
    if (kIsWeb) return 'Браузер';

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.android => 'Android',
      _ => 'Компьютер',
    };
  }

  void _handleTokenRejected() {
    _tokens.clear();
    resident = null;
    stage = AuthStage.signedOut;
    notifyListeners();

    // Доступ отозван — напоминания прежнего человека здесь тоже лишние
    unawaited(Reminders.cancelEverything());
  }

  void _set({AuthStage? stage, bool? busy, Object? error = _unset}) {
    if (stage != null) this.stage = stage;
    if (busy != null) this.busy = busy;
    if (!identical(error, _unset)) this.error = error as String?;
    notifyListeners();
  }

  static const _unset = Object();
}
