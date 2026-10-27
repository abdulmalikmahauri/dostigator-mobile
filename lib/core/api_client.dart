import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

/// Ошибка, которую не стыдно показать резиденту.
///
/// Бэкенд отвечает по-русски и по делу («Осталось попыток: 2»), поэтому
/// его сообщение и выносим на экран. Свои формулировки — только там,
/// где сервер не ответил вовсе.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ApiClient {
  // ignore: prefer_initializing_formals — Dart запрещает приватные имена
  // у именованных параметров, поэтому this._tokens здесь недоступен.
  ApiClient({required TokenStorage tokens, Dio? dio})
    : _tokens = tokens,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl + ApiConfig.apiPrefix,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              headers: {'Accept': 'application/json'},
              // Разбираем коды сами: 422 с текстом ошибки полезнее исключения
              validateStatus: (code) => code != null && code < 500,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// Вызывается, когда сервер сообщил, что токен больше не действует.
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(() => _dio.post(path, data: body));

  Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(() => _dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(() => _dio.delete(path, data: body));

  /// Загрузка файла одним полем формы. Байты, а не путь: на вебе пути
  /// к файлу нет, а байты есть на всех платформах.
  Future<Map<String, dynamic>> upload(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) => _send(
    () => _dio.post(
      path,
      data: FormData.fromMap({
        field: MultipartFile.fromBytes(bytes, filename: filename),
      }),
    ),
  );

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    late final Response<dynamic> response;

    try {
      response = await request();
    } on DioException catch (e) {
      throw ApiException(_describeNetworkFailure(e));
    }

    final status = response.statusCode ?? 0;
    final data = response.data;

    if (status == 401) {
      onUnauthorized?.call();
      throw ApiException('Сессия истекла — войдите заново', statusCode: 401);
    }

    if (status >= 400) {
      throw _describeServerRejection(status, data);
    }

    if (data is Map<String, dynamic>) return data;
    if (data == null || (data is String && data.isEmpty)) return const {};

    return {'data': data};
  }

  ApiException _describeServerRejection(int status, dynamic data) {
    final fields = <String, List<String>>{};
    var message = 'Не удалось выполнить запрос';

    if (data is Map<String, dynamic>) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        message = data['message'] as String;
      }

      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        for (final entry in errors.entries) {
          final list = entry.value;
          if (list is List) {
            fields[entry.key] = list.map((e) => e.toString()).toList();
          }
        }
        // Текст первой ошибки поля точнее общего «данные не прошли проверку»
        if (fields.isNotEmpty && fields.values.first.isNotEmpty) {
          message = fields.values.first.first;
        }
      }
    }

    if (status == 429) {
      message = 'Слишком часто. Подождите немного и повторите.';
    }

    return ApiException(message, statusCode: status, fieldErrors: fields);
  }

  String _describeNetworkFailure(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Сервер не отвечает. Проверьте интернет и попробуйте снова.',
      DioExceptionType.connectionError =>
        'Нет связи с сервером. Проверьте интернет.',
      DioExceptionType.badCertificate => 'Проблема с сертификатом сервера.',
      _ => 'Что-то пошло не так. Попробуйте ещё раз.',
    };
  }
}
