import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/club_time.dart';
import '../models/plan.dart';
import '../models/task.dart';
import 'safe_notifier.dart';

/// План по дням и статистика сделанного.
class PlanController extends ChangeNotifier with SafeNotifier {
  PlanController(this._api, {DateTime Function()? today})
    : _today = today ?? ClubTime.today;

  final ApiClient _api;
  final DateTime Function() _today;

  /// Сколько дней показываем за раз и на сколько дописываем по кнопке.
  static const step = 7;

  /// Сколько дней в статистике.
  static const statsDays = 14;

  /// Дальше двух месяцев сервер за раз не отдаёт.
  static const maxDays = 62;

  List<PlanDay> days = const [];
  List<Task> overdue = const [];
  PlannerStats? stats;
  int _shown = step;
  bool loading = false;
  bool loaded = false;
  bool loadingMore = false;
  String? error;

  /// Номер последней загрузки: опоздавший ответ на прежнюю не применяется.
  int _request = 0;

  static final _day = DateFormat('yyyy-MM-dd');

  bool get canShowMore => _shown < maxDays;

  /// true — данные пришли и применены.
  Future<bool> load({bool silent = false}) async {
    final request = ++_request;

    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final from = _today();
    final to = from.add(Duration(days: _shown - 1));

    try {
      final results = await Future.wait([
        _api.get(
          '/planner',
          query: {'from': _day.format(from), 'to': _day.format(to)},
        ),
        _api.get('/planner/stats', query: {'days': '$statsDays'}),
      ]);

      if (request != _request) return false;

      final plan = PlanResponse.fromJson(
        results[0]['data'] as Map<String, dynamic>? ?? const {},
      );
      days = plan.days;
      overdue = plan.overdue;
      stats = PlannerStats.fromJson(
        results[1]['data'] as Map<String, dynamic>? ?? const {},
      );
      loaded = true;
      error = null;

      return true;
    } on ApiException catch (e) {
      if (request == _request) error = e.message;

      return false;
    } finally {
      if (request == _request) loading = false;
      notifyListeners();
    }
  }

  /// Ещё неделя вперёд. Не вышло — остаётся столько дней, сколько было.
  Future<void> showMore() async {
    if (!canShowMore || loadingMore) return;

    final before = _shown;
    _shown = (_shown + step).clamp(step, maxDays);
    loadingMore = true;
    notifyListeners();

    final ok = await load(silent: true);
    if (!ok) _shown = before;

    loadingMore = false;
    notifyListeners();
  }
}
