import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/habit.dart';
import 'safe_notifier.dart';

/// Мои привычки и общие привычки клуба.
class HabitsController extends ChangeNotifier with SafeNotifier {
  HabitsController(this._api);

  final ApiClient _api;

  List<Habit> habits = const [];
  bool loading = false;
  bool loaded = false;
  String? error;

  static final _day = DateFormat('yyyy-MM-dd');

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final response = await _api.get('/habits');
      habits = _habits(response['data']);
      loaded = true;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Ошибку сервера пробрасываем целиком: у неё замечания к полям формы.
  Future<Habit> create(HabitDraft draft) async {
    final response = await _api.post('/habits', draft.toJson());
    final habit = Habit.fromJson(response['data'] as Map<String, dynamic>);

    habits = [...habits, habit];
    notifyListeners();

    return habit;
  }

  /// Свою норму — любой участник; остальное — только автор своей привычки.
  Future<Habit> update(int id, Map<String, dynamic> changes) async {
    final response = await _api.patch('/habits/$id', changes);
    final habit = Habit.fromJson(response['data'] as Map<String, dynamic>);

    _replace(habit);
    return habit;
  }

  Future<String?> leave(int id) async {
    try {
      await _api.delete('/habits/$id');
      habits = habits.where((h) => h.id != id).toList();
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Отметка за день. Сегодняшняя видна сразу — человек нажал и ждать
  /// ответа сервера не должен. Если сервер отказал, возвращаем как было.
  Future<String?> log(int id, DateTime date, int value) async {
    // Пока отметка уходит, второе нажатие по той же привычке ждёт
    if (!_logging.add(id)) return null;

    final index = habits.indexWhere((h) => h.id == id);
    final before = index >= 0 ? habits[index] : null;

    if (before != null && before.today.date == date) {
      _replace(before.withToday(value: value, done: value >= before.target));
    }

    try {
      final response = await _api.post('/habits/$id/log', {
        'date': _day.format(date),
        'value': value,
      });
      _replace(Habit.fromJson(response['data'] as Map<String, dynamic>));

      return null;
    } on ApiException catch (e) {
      // Возвращаем как было только эту привычку: остальные могли поменяться
      if (before != null) _replace(before);

      return e.message;
    } finally {
      _logging.remove(id);
    }
  }

  final Set<int> _logging = {};

  /// Привычка целиком: месяц по дням и рейтинг, если она общая.
  Future<Habit> detail(int id) async {
    final response = await _api.get('/habits/$id');
    return Habit.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<ListedHabit>> catalog({String? query}) async {
    final q = query?.trim();
    final response = await _api.get(
      '/habits/public',
      query: q == null || q.isEmpty ? null : {'q': q},
    );

    return _listed(response['data']);
  }

  /// Похожие общие привычки — чтобы присоединиться, а не заводить такую же.
  Future<List<ListedHabit>> suggest(String title) async {
    final response = await _api.get(
      '/habits/suggest',
      query: {'title': title.trim()},
    );

    return _listed(response['data']);
  }

  Future<Habit> join(int id, int target) async {
    final response = await _api.post('/habits/$id/join', {'target': target});
    final habit = Habit.fromJson(response['data'] as Map<String, dynamic>);

    habits = [...habits.where((h) => h.id != id), habit];
    notifyListeners();

    return habit;
  }

  Future<List<HabitRatingRow>> rating() async {
    final response = await _api.get('/habits/rating');

    return (response['data'] as List<dynamic>? ?? const [])
        .map((r) => HabitRatingRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  void _replace(Habit habit) {
    habits = [for (final h in habits) h.id == habit.id ? habit : h];
    notifyListeners();
  }

  List<Habit> _habits(dynamic data) => (data as List<dynamic>? ?? const [])
      .map((h) => Habit.fromJson(h as Map<String, dynamic>))
      .toList();

  List<ListedHabit> _listed(dynamic data) =>
      (data as List<dynamic>? ?? const [])
          .map((h) => ListedHabit.fromJson(h as Map<String, dynamic>))
          .toList();
}
