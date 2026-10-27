import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/reminders.dart';
import '../models/goal.dart';

/// Шаг в форме цели: у уже сохранённого есть [id], у нового — нет.
/// По id сервер понимает, какой шаг переименовали, а какой добавили.
class GoalStepDraft {
  const GoalStepDraft({this.id, required this.title});

  final int? id;
  final String title;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title.trim(),
  };
}

class GoalsController extends ChangeNotifier {
  GoalsController(this._api);

  final ApiClient _api;

  List<Goal> goals = const [];
  bool loading = false;
  bool busy = false;
  String? error;

  /// Цели в работе. Порядок задаёт сервер: главная первой, дальше по сроку.
  List<Goal> get activeGoals => goals.where((g) => g.isActive).toList();

  /// Главная цель. Если сервер по какой-то причине не пометил ни одну,
  /// берём первую в списке — экран не должен остаться без цели.
  Goal? get mainGoal {
    final active = activeGoals;
    if (active.isEmpty) return null;

    return active.firstWhere((g) => g.isMain, orElse: () => active.first);
  }

  /// Остальные цели в работе — всё, кроме главной.
  List<Goal> get otherGoals {
    final main = mainGoal;

    return activeGoals.where((g) => g.id != main?.id).toList();
  }

  /// Цели, по которым на этой неделе ещё нет отчёта.
  List<Goal> get pendingCheckins =>
      activeGoals.where((g) => !g.checkedInThisWeek).toList();

  Goal? byId(int id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<Goal> get archive => goals.where((g) => !g.isActive).toList();

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final response = await _api.get('/goals');
      final list = response['data'] as List<dynamic>? ?? const [];
      goals = list
          .map((e) => Goal.fromJson(e as Map<String, dynamic>))
          .toList();
      error = null;
      // В фоне: показать цели важнее, чем дождаться службы уведомлений
      unawaited(_syncReminders());
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Приводит напоминания в соответствие с текущим состоянием целей.
  ///
  /// Вызывается после каждой загрузки, а не точечно после чек-ина:
  /// так расписание остаётся верным, даже если цель закрыли с другого
  /// устройства или через админку.
  ///
  /// Сбой уведомлений здесь глушится: цели уже загружены, и показать их
  /// важнее, чем поставить напоминание.
  Future<void> _syncReminders() async {
    final pending = pendingCheckins;

    try {
      if (pending.isEmpty) {
        await Reminders.cancelCheckin();

        return;
      }

      await Reminders.scheduleCheckin(
        goalTitles: pending.map((g) => g.title).toList(),
      );
    } on Exception catch (e) {
      debugPrint('Напоминания о чек-ине не обновлены: $e');
    }
  }

  Future<String?> create({
    required String title,
    String? why,
    required String metricName,
    String? metricUnit,
    required double from,
    required double target,
    required DateTime deadline,
    List<String> steps = const [],
    bool hideAbsoluteValues = false,
  }) async {
    return _mutate(
      () => _api.post('/goals', {
        'title': title,
        if (why != null && why.isNotEmpty) 'why': why,
        'metric_name': metricName,
        if (metricUnit != null && metricUnit.isNotEmpty)
          'metric_unit': metricUnit,
        'metric_from': from,
        'metric_target': target,
        'deadline': _date(deadline),
        'hide_absolute_values': hideAbsoluteValues,
        'steps': steps
            .where((s) => s.trim().isNotEmpty)
            .map((s) => {'title': s.trim()})
            .toList(),
      }),
    );
  }

  Future<String?> checkin({
    required int goalId,
    required double value,
    String? comment,
    bool needsHelp = false,
  }) async {
    return _mutate(
      () => _api.post('/goals/$goalId/checkin', {
        'metric_value': value,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        'needs_help': needsHelp,
      }),
    );
  }

  Future<String?> toggleStep(int goalId, int stepId) {
    return _mutate(() => _api.post('/goals/$goalId/steps/$stepId/toggle'));
  }

  /// Правка цели целиком — тем же набором полей, что и при постановке.
  /// Шаги уходят списком: чего в нём нет, то сервер удалит.
  Future<String?> update({
    required int goalId,
    required String title,
    String? why,
    required String metricName,
    String? metricUnit,
    required double from,
    required double target,
    required DateTime deadline,
    List<GoalStepDraft> steps = const [],
    bool hideAbsoluteValues = false,
  }) {
    return updateGoal(goalId, {
      'title': title,
      'why': (why == null || why.isEmpty) ? null : why,
      'metric_name': metricName,
      'metric_unit': (metricUnit == null || metricUnit.isEmpty)
          ? null
          : metricUnit,
      'metric_from': from,
      'metric_target': target,
      'deadline': _date(deadline),
      'hide_absolute_values': hideAbsoluteValues,
      'steps': steps
          .where((s) => s.title.trim().isNotEmpty)
          .map((s) => s.toJson())
          .toList(),
    });
  }

  Future<String?> makeMain(int goalId) => updateGoal(goalId, {'is_main': true});

  /// Закрыть цель: `achieved` — взята, `dropped` — больше не актуальна.
  Future<String?> close(int goalId, String status) =>
      updateGoal(goalId, {'status': status});

  Future<String?> updateGoal(int goalId, Map<String, dynamic> changes) {
    return _mutate(() => _api.patch('/goals/$goalId', changes));
  }

  /// @return текст ошибки для показа, либо null при успехе
  Future<String?> _mutate(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    busy = true;
    notifyListeners();

    try {
      await request();
      await load(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
