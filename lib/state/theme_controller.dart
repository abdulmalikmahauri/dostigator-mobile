import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Где хранится выбранная тема. Отдельный интерфейс — чтобы тесты
/// не зависели от платформенного плагина.
abstract interface class ThemeStorage {
  Future<String?> read();

  Future<void> write(String value);
}

/// Хранилище на SharedPreferences: тема — не секрет, Keychain ей не нужен.
class PrefsThemeStorage implements ThemeStorage {
  static const _key = 'theme_mode';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);
}

/// Светлая или тёмная тема. По умолчанию — тёмная, фирменная: за системой
/// не следуем, чтобы приложение открывалось узнаваемым, а светлую человек
/// включает сам кнопкой в шапке.
class ThemeController extends ChangeNotifier {
  ThemeController(this._storage);

  final ThemeStorage _storage;

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  bool get isLight => _mode == ThemeMode.light;

  /// Восстановить сохранённый выбор. Ошибки хранилища не критичны:
  /// без сохранённого значения просто остаёмся на тёмной.
  Future<void> restore() async {
    try {
      final saved = await _storage.read();
      if (saved == ThemeMode.light.name) {
        _mode = ThemeMode.light;
        notifyListeners();
      }
    } on Exception {
      // Хранилище недоступно (приватный режим браузера, сбой диска) —
      // тема остаётся тёмной, приложение от этого не страдает
    }
  }

  Future<void> toggle() async {
    _mode = isLight ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    try {
      await _storage.write(_mode.name);
    } on Exception {
      // Не сохранилось — переключение всё равно сработало до перезапуска
    }
  }
}
