import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/event.dart';
import 'package:dostigator/models/event_proposal.dart';
import 'package:dostigator/models/meeting.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/events_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'theme.dart';

/// Контроллер без сети: экраны зовут загрузку в initState, и без заглушки
/// сетевая ошибка перетёрла бы подготовленное тестом состояние.
/// Что экран попросил сделать — записывается для проверки.
class StubEventsController extends EventsController {
  StubEventsController(super.api);

  List<EventPhoto> photosResult = const [];
  final List<EventProposalDraft> proposed = [];
  final List<int> withdrawn = [];
  final List<DateTime> monthsLoaded = [];
  int pastLoads = 0;

  /// Чем ответит «сервер» на предложение; null — принял.
  ApiException? proposeError;

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<void> loadPast() async => pastLoads++;

  @override
  Future<void> loadMonth(DateTime anyDay) async {
    monthsLoaded.add(anyDay);
    month = DateTime.utc(anyDay.year, anyDay.month);
    notifyListeners();
  }

  @override
  Future<void> loadProposals() async {}

  @override
  Future<List<EventPhoto>> photos(int eventId) async => photosResult;

  @override
  Future<void> propose(EventProposalDraft draft) async {
    if (proposeError != null) throw proposeError!;
    proposed.add(draft);
  }

  @override
  Future<String?> withdraw(int proposalId) async {
    withdrawn.add(proposalId);
    proposals = proposals.where((p) => p.id != proposalId).toList();
    notifyListeners();

    return null;
  }
}

ClubEvent testEvent({
  int id = 1,
  String title = 'Бизнес-завтрак',
  String startsAt = '2026-09-20T09:00:00+03:00',
  String? endsAt,
  bool isPast = false,
  bool isFull = false,
  bool isAvailable = true,
  bool isRegistered = false,
  bool checkedIn = false,
  int? seatsLeft,
  int? capacity,
  String? ticket,
  String? place,
  String? description,
  String? speaker,
  String format = 'offline',
  String? topic,
  int photosCount = 0,
  String? photosLink,
  List<Map<String, dynamic>> partners = const [],
}) {
  return ClubEvent.fromJson({
    'id': id,
    'title': title,
    'type': 'breakfast',
    'type_label': 'Встреча клуба',
    'format': format,
    'format_label': switch (format) {
      'online' => 'Онлайн',
      'hybrid' => 'Очно и онлайн',
      _ => 'Очно',
    },
    'topic': topic,
    'starts_at': startsAt,
    'ends_at': endsAt,
    'place': place,
    'description': description,
    'speaker': speaker,
    'price': 0,
    'is_free': true,
    'is_past': isPast,
    'capacity': capacity,
    'seats_left': seatsLeft,
    'is_full': isFull,
    'is_available': isAvailable,
    'is_registered': isRegistered,
    'checked_in': checkedIn,
    'ticket': ticket,
    'photos_count': photosCount,
    'photos_link': photosLink,
    'partners': partners,
  });
}

Meeting testMeeting({
  int id = 1,
  String title = 'Заседание клуба',
  String scheduledAt = '2026-11-12T19:00:00+00:00',
  String myStatus = 'expected',
  String myStatusLabel = 'Ожидается',
  bool isPast = false,
}) {
  return Meeting.fromJson({
    'id': id,
    'title': title,
    'scheduled_at': scheduledAt,
    'place': 'Офис экосистемы',
    'audience': 'club',
    'audience_label': 'Весь бизнес-клуб',
    'is_past': isPast,
    'my_status': myStatus,
    'my_status_label': myStatusLabel,
  });
}

EventProposal testProposal({
  int id = 1,
  String title = 'Разбор воронок',
  String status = 'pending',
  String statusLabel = 'На согласовании',
  String? reason,
}) {
  return EventProposal.fromJson({
    'id': id,
    'title': title,
    'type_label': 'Семинар',
    'format_label': 'Онлайн',
    'starts_at': '2026-11-20T19:00:00+00:00',
    'status': status,
    'status_label': statusLabel,
    'rejection_reason': reason,
  });
}

Widget wrapEvents(
  Widget child, {
  required EventsController events,
  ApiClient? api,
}) {
  final client = api ?? unreachableApi();

  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: client, tokens: MemoryTokenStorage()),
      ),
      ChangeNotifierProvider<EventsController>.value(value: events),
    ],
    child: MaterialApp(
      theme: buildDostigatorTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

/// Экран длиннее тестового окна, а ListView строит только видимое —
/// без высокого окна нижние блоки не дошли бы до отрисовки.
void tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}
