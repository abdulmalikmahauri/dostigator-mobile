import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/task.dart';
import 'safe_notifier.dart';

/// Мои задачи: в работе и сделанные.
class TasksController extends ChangeNotifier with SafeNotifier {
  TasksController(this._api);

  final ApiClient _api;

  List<Task> open = const [];
  List<Task> done = const [];
  bool loading = false;
  bool loaded = false;
  String? error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _api.get('/tasks'),
        _api.get('/tasks', query: {'status': 'done'}),
      ]);

      open = _tasks(results[0]['data']);
      done = _tasks(results[1]['data']);
      loaded = true;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Ошибку сервера пробрасываем: у неё замечания к полям формы.
  Future<Task> create(TaskDraft draft) async {
    final response = await _api.post('/tasks', draft.toJson());
    final task = Task.fromJson(response['data'] as Map<String, dynamic>);

    open = _sorted([...open, task]);
    notifyListeners();

    return task;
  }

  Future<Task> update(int id, TaskDraft draft) async {
    final response = await _api.patch('/tasks/$id', draft.toJson());
    final task = Task.fromJson(response['data'] as Map<String, dynamic>);

    _place(task);
    return task;
  }

  /// «Сделано» видно сразу; если сервер отказал — возвращаем как было.
  Future<String?> toggle(int id) async {
    final current = _find(id);
    if (current == null) {
      try {
        await _api.post('/tasks/$id/toggle');
        return null;
      } on ApiException catch (e) {
        return e.message;
      }
    }

    if (!_toggling.add(id)) return null;
    _place(current.toggled());

    try {
      final response = await _api.post('/tasks/$id/toggle');
      _place(Task.fromJson(response['data'] as Map<String, dynamic>));

      return null;
    } on ApiException catch (e) {
      // Возвращаем как было только эту задачу: остальные могли поменяться
      _place(current);

      return e.message;
    } finally {
      _toggling.remove(id);
    }
  }

  final Set<int> _toggling = {};

  Future<String?> delete(int id) async {
    try {
      await _api.delete('/tasks/$id');
      open = open.where((t) => t.id != id).toList();
      done = done.where((t) => t.id != id).toList();
      notifyListeners();

      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Task? _find(int id) {
    for (final t in [...open, ...done]) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Ставит задачу в нужный список — в работе или сделанные.
  void _place(Task task) {
    final restOpen = open.where((t) => t.id != task.id);
    final restDone = done.where((t) => t.id != task.id);

    open = task.isDone ? restOpen.toList() : _sorted([...restOpen, task]);
    done = task.isDone ? [task, ...restDone] : restDone.toList();
    notifyListeners();
  }

  /// Как на сервере: сначала со сроком — по ближайшему, потом без срока.
  List<Task> _sorted(List<Task> tasks) => [...tasks]
    ..sort((a, b) {
      final ad = a.dueOn;
      final bd = b.dueOn;
      if (ad == null && bd == null) return a.id.compareTo(b.id);
      if (ad == null) return 1;
      if (bd == null) return -1;
      final byDate = ad.compareTo(bd);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  List<Task> _tasks(dynamic data) => (data as List<dynamic>? ?? const [])
      .map((t) => Task.fromJson(t as Map<String, dynamic>))
      .toList();
}
