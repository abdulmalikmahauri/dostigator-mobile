import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/club_time.dart';
import 'package:dostigator/models/event_proposal.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/events_controller.dart';
import 'package:dostigator/state/session_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/api.dart';
import 'helpers/events.dart';

class _TestAuth extends AuthController {
  _TestAuth(ApiClient api) : super(api: api, tokens: MemoryTokenStorage());

  void go(AuthStage value) {
    stage = value;
    notifyListeners();
  }
}

/// Ответы приходят тогда, когда скажет тест, — в любом порядке.
class _ManualAdapter implements HttpClientAdapter {
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

  /// Ответить на n-й по счёту запрос к [path] за [month].
  void reply(String path, String month, int nth, Map<String, dynamic> body) {
    final matching = pending
        .where(
          (p) => p.$1.path == path && p.$1.queryParameters['month'] == month,
        )
        .toList();

    matching[nth].$2.complete(
      ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _monthOf(String title) => {
  'data': [
    {'id': 1, 'title': title, 'starts_at': '2026-11-12T09:00:00+00:00'},
  ],
};

void main() {
  testWidgets('выход из аккаунта выбрасывает данные прошлого входа', (
    tester,
  ) async {
    final api = unreachableApi();
    final auth = _TestAuth(api)..stage = AuthStage.signedIn;
    EventsController? seen;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: SessionScope(
          api: api,
          child: Builder(
            builder: (context) {
              seen = context.watch<EventsController>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final before = seen!..proposals = [testProposal()];

    auth.go(AuthStage.signedOut);
    await tester.pump();
    auth.go(AuthStage.signedIn);
    await tester.pump();

    expect(identical(seen, before), isFalse);
    expect(seen!.proposals, isEmpty);
  });

  test('опоздавший ответ про тот же месяц не затирает свежий', () async {
    final adapter = _ManualAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://stub.test/api/v1'))
      ..httpClientAdapter = adapter;
    final c = EventsController(
      ApiClient(tokens: MemoryTokenStorage(), dio: dio),
    );

    // Ноябрь → декабрь → снова ноябрь: по два запроса на каждый
    final first = c.loadMonth(DateTime.utc(2026, 11));
    final second = c.loadMonth(DateTime.utc(2026, 12));
    final third = c.loadMonth(DateTime.utc(2026, 11));
    for (var i = 0; i < 100 && adapter.pending.length < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    // Сначала приходит ответ на последний запрос, потом — на самый первый
    adapter
      ..reply('/events', '2026-11', 1, _monthOf('Свежее'))
      ..reply('/meetings', '2026-11', 1, {'data': []});
    await third;
    adapter
      ..reply('/events', '2026-11', 0, _monthOf('Устаревшее'))
      ..reply('/meetings', '2026-11', 0, {'data': []})
      ..reply('/events', '2026-12', 0, {'data': []})
      ..reply('/meetings', '2026-12', 0, {'data': []});
    await Future.wait([first, second]);

    expect(c.month, DateTime.utc(2026, 11));
    expect(c.monthEvents.single.title, 'Свежее');
    expect(c.monthLoading, isFalse);
  });

  test(
    'сервер принял предложение, но ответил странно — список перечитан',
    () async {
      final (:api, :stub) = stubbedApi((call) {
        if (call.method == 'POST') return (201, {'data': null});
        return (
          200,
          {
            'data': [
              {
                'id': 9,
                'title': 'Разбор воронок',
                'starts_at': '2026-11-20T19:00:00+00:00',
                'status': 'pending',
              },
            ],
          },
        );
      });
      final c = EventsController(api);

      await c.propose(
        EventProposalDraft(
          title: 'Разбор воронок',
          type: 'seminar',
          format: 'online',
          startsAt: DateTime.utc(2026, 11, 20, 19),
        ),
      );

      expect(c.proposals.single.id, 9);
      expect(stub.calls.last.method, 'GET');
    },
  );

  group('Клубное время', () {
    tearDown(() => ClubTime.clock = DateTime.now);

    /// Резидент в отъезде: у него ещё вечер, а в Москве уже завтра.
    test('«сегодня» — по Москве, а не по часам телефона', () {
      ClubTime.clock = () => DateTime.utc(2026, 11, 10, 22, 30);

      expect(ClubTime.today(), DateTime.utc(2026, 11, 11));
      expect(ClubTime.now().hour, 1);
    });
  });
}
