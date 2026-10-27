import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Токен доступа в защищённом хранилище системы (Android Keystore).
///
/// SharedPreferences здесь не подходит: это обычный XML в песочнице
/// приложения, доступный на устройстве с root и в бэкапах.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
