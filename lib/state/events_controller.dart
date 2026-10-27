import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/event.dart';
import '../models/event_filter.dart';
import '../models/event_proposal.dart';
import '../models/meeting.dart';
import 'safe_notifier.dart';

class EventsController extends ChangeNotifier with SafeNotifier {
  EventsController(this._api);

  final ApiClient _api;

  List<ClubEvent> upcoming = const [];
  List<ClubEvent> mine = const [];

  /// Ближайшие заседания, на которых ждут этого резидента.
  List<Meeting> meetings = const [];

  bool loading = false;
  int? busyEventId;
  String? error;

  /// Фильтр общий для афиши и прошедших: переключился между ними —
  /// поиск остался тем же.
  EventFilter filter = EventFilter.none;

  // Прошедшие грузятся, только когда их открыли: это вторая вкладка,
  // и тянуть архив при каждом входе в «События» незачем
  List<ClubEvent> past = const [];
  List<Meeting> pastMeetings = const [];
  MeetingAttendance attendance = MeetingAttendance.empty;
  bool pastLoading = false;
  bool pastLoaded = false;
  String? pastError;

  /// Первое число открытого в календаре месяца.
  DateTime? month;
  List<ClubEvent> monthEvents = const [];
  List<Meeting> monthMeetings = const [];
  bool monthLoading = false;
  String? monthError;

  /// Номер последнего запроса месяца: опоздавший ответ на более ранний
  /// запрос — даже про тот же месяц — уже не применяется.
  int _monthRequest = 0;

  List<EventProposal> proposals = const [];
  bool proposalsLoading = false;
  String? proposalsError;

  static final _monthParam = DateFormat('yyyy-MM');

  /// Ближайшее мероприятие, на которое резидент записан — для главной.
  ClubEvent? get nextRegistered {
    final future = mine.where((e) => !e.isPast).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return future.isEmpty ? null : future.first;
  }

  Set<int> get monthEventDays => {for (final e in monthEvents) e.startsAt.day};

  Set<int> get monthMeetingDays => {
    for (final m in monthMeetings) m.scheduledAt.day,
  };

  /// Свежая копия мероприятия по id — из любого загруженного списка.
  /// `mine` первым: только там у события есть билет.
  ClubEvent? find(int id) {
    for (final list in [mine, upcoming, past, monthEvents]) {
      for (final e in list) {
        if (e.id == id) return e;
      }
    }
    return null;
  }

  void setFilter(EventFilter value) {
    filter = value;
    notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _api.get('/events'),
        _api.get('/events/my'),
        _optional('/meetings'),
      ]);

      upcoming = _events(results[0]);
      mine = _events(results[1]);
      if (results[2] != null) meetings = _meetings(results[2]);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadPast() async {
    pastLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.get('/events', query: {'scope': 'past'}),
        _optional('/meetings', {'scope': 'past'}),
      ]);

      past = _events(results[0]);
      final meetingsResponse = results[1];
      if (meetingsResponse != null) {
        pastMeetings = _meetings(meetingsResponse);
        attendance = _attendance(meetingsResponse);
      }
      pastLoaded = true;
      pastError = null;
    } on ApiException catch (e) {
      pastError = e.message;
    } finally {
      pastLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMonth(DateTime anyDay) async {
    final first = DateTime.utc(anyDay.year, anyDay.month);
    final request = ++_monthRequest;

    // Пока грузится новый месяц, старые отметки не должны висеть на чужих днях
    if (month != first) {
      monthEvents = const [];
      monthMeetings = const [];
    }
    month = first;
    monthLoading = true;
    notifyListeners();

    final query = {'month': _monthParam.format(first)};

    try {
      final results = await Future.wait([
        _api.get('/events', query: query),
        _optional('/meetings', query),
      ]);

      // Пока шёл запрос, резидент мог перелистнуть или обновить
      // ещё раз — тогда этот ответ уже устарел
      if (request != _monthRequest) return;

      monthEvents = _events(results[0]);
      // Заседания не отдались — оставляем те, что уже были на экране
      if (results[1] != null) monthMeetings = _meetings(results[1]);
      monthError = null;
    } on ApiException catch (e) {
      if (request == _monthRequest) monthError = e.message;
    } finally {
      if (request == _monthRequest) monthLoading = false;
      notifyListeners();
    }
  }

  Future<List<EventPhoto>> photos(int eventId) async {
    final response = await _api.get('/events/$eventId/photos');
    final list = response['data'] as List<dynamic>? ?? const [];

    return list
        .map((p) => EventPhoto.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadProposals() async {
    proposalsLoading = true;
    notifyListeners();

    try {
      final response = await _api.get('/events/proposals');
      proposals = _proposals(response);
      proposalsError = null;
    } on ApiException catch (e) {
      proposalsError = e.message;
    } finally {
      proposalsLoading = false;
      notifyListeners();
    }
  }

  /// Отправить предложение организаторам. Ошибку сервера пробрасываем
  /// целиком — у неё могут быть замечания к конкретным полям формы.
  Future<void> propose(EventProposalDraft draft) async {
    final response = await _api.post('/events/proposals', draft.toJson());
    final data = response['data'];

    // Сервер предложение уже принял. Если ответ разобрать не вышло,
    // просто перечитываем список — второй раз отправлять нельзя
    try {
      if (data is! Map<String, dynamic>) throw const FormatException();
      proposals = [EventProposal.fromJson(data), ...proposals];
      notifyListeners();
    } on FormatException {
      await loadProposals();
    }
  }

  Future<String?> withdraw(int proposalId) async {
    try {
      await _api.delete('/events/proposals/$proposalId');
      proposals = proposals.where((p) => p.id != proposalId).toList();
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      // Скорее всего, предложение уже рассмотрели — показываем, что решили
      await loadProposals();

      return e.message;
    }
  }

  /// Заседания — дополнение к афише: их сбой не должен прятать мероприятия.
  Future<Map<String, dynamic>?> _optional(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      return await _api.get(path, query: query);
    } on ApiException {
      return null;
    }
  }

  List<ClubEvent> _events(Map<String, dynamic>? response) =>
      (response?['data'] as List<dynamic>? ?? const [])
          .map((e) => ClubEvent.fromJson(e as Map<String, dynamic>))
          .toList();

  List<Meeting> _meetings(Map<String, dynamic>? response) =>
      (response?['data'] as List<dynamic>? ?? const [])
          .map((m) => Meeting.fromJson(m as Map<String, dynamic>))
          .toList();

  MeetingAttendance _attendance(Map<String, dynamic> response) {
    final meta = response['meta'] as Map<String, dynamic>?;

    return MeetingAttendance.fromJson(
      meta?['attendance'] as Map<String, dynamic>?,
    );
  }

  List<EventProposal> _proposals(Map<String, dynamic> response) =>
      (response['data'] as List<dynamic>? ?? const [])
          .map((p) => EventProposal.fromJson(p as Map<String, dynamic>))
          .toList();

  Future<String?> register(int eventId) => _act(eventId, 'register');

  Future<String?> cancel(int eventId) => _act(eventId, 'cancel');

  Future<String?> _act(int eventId, String action) async {
    busyEventId = eventId;
    notifyListeners();

    try {
      await _api.post('/events/$eventId/$action');
      // Перечитываем оба списка: изменилось и число мест в афише,
      // и состав моих регистраций
      await load(silent: true);

      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      busyEventId = null;
      notifyListeners();
    }
  }
}
