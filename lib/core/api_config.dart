/// Адрес бэкенда задаётся при сборке:
///
///   flutter build apk --dart-define=API_BASE_URL=https://api.dostigator.org
///
/// Значение по умолчанию — 10.0.2.2: так эмулятор Android видит localhost
/// хост-машины. На реальном телефоне этот адрес не сработает, поэтому
/// для APK параметр сборки обязателен.
class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );

  static const apiPrefix = '/api/v1';

  static String url(String path) => '$baseUrl$apiPrefix$path';

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 25);
}
