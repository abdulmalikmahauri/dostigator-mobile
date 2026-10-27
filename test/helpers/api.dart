import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище токена в памяти: настоящее лезет в Android Keystore,
/// которого в тестах нет.
class MemoryTokenStorage extends TokenStorage {
  MemoryTokenStorage() : super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// Один запрос, как его увидел бы сервер.
class StubCall {
  const StubCall(this.method, this.path, this.body, [this.query = const {}]);

  final String method;
  final String path;

  /// Параметры адресной строки: ?scope=past&month=2026-11.
  final Map<String, dynamic> query;

  /// Тело запроса, если оно было JSON-объектом.
  final Map<String, dynamic>? body;

  @override
  String toString() => '$method $path';
}

/// Управляемые ответы сервера: запросы никуда не уходят, а тест задаёт,
/// что вернул бэкенд, и потом смотрит, что именно у него просили.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.handler);

  final (int, Map<String, dynamic>) Function(StubCall call) handler;

  final List<StubCall> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    final call = StubCall(
      options.method,
      options.path,
      data is Map<String, dynamic> ? data : null,
      options.queryParameters,
    );
    calls.add(call);

    final (code, body) = handler(call);

    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Клиент API, который разговаривает с заглушкой вместо сервера.
({ApiClient api, StubAdapter stub}) stubbedApi(
  (int, Map<String, dynamic>) Function(StubCall call) handler,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://stub.test/api/v1',
      // Как в боевом клиенте: отказ сервера — это ответ, а не сбой сети
      validateStatus: (code) => code != null && code < 500,
    ),
  );
  final stub = StubAdapter(handler);
  dio.httpClientAdapter = stub;

  return (api: ApiClient(tokens: MemoryTokenStorage(), dio: dio), stub: stub);
}

/// Клиент API без сети: любой запрос завершается ошибкой связи.
ApiClient unreachableApi() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));

  return ApiClient(tokens: MemoryTokenStorage(), dio: dio);
}
