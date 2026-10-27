import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';

import 'api.dart';

/// Сервер, который отвечает тогда, когда скажет тест, — в любом порядке.
class ManualAdapter implements HttpClientAdapter {
  final List<(RequestOptions, Completer<ResponseBody>)> pending = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final completer = Completer<ResponseBody>();
    pending.add((options, completer));
    return completer.future;
  }

  /// Ответить на n-й по счёту запрос, подходящий под условие.
  void reply(
    bool Function(RequestOptions o) where,
    Map<String, dynamic> body, {
    int nth = 0,
    int status = 200,
  }) {
    final matching = pending.where((p) => where(p.$1)).toList();

    matching[nth].$2.complete(
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  /// Дождаться, пока до «сервера» дойдут [count] запросов.
  Future<void> waitFor(int count) async {
    for (var i = 0; i < 200 && pending.length < count; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient api, ManualAdapter adapter}) manualApi() {
  final adapter = ManualAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://stub.test/api/v1',
      validateStatus: (code) => code != null && code < 500,
    ),
  )..httpClientAdapter = adapter;

  return (
    api: ApiClient(tokens: MemoryTokenStorage(), dio: dio),
    adapter: adapter,
  );
}
