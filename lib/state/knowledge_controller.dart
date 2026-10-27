import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/knowledge.dart';
import 'safe_notifier.dart';

/// Какие материалы показать: все или только один вид.
enum CourseKindFilter {
  all(null, 'Все'),
  course('course', 'Курсы'),
  lecture('lecture', 'Лекции'),
  masterclass('masterclass', 'Мастер-классы');

  const CourseKindFilter(this.value, this.label);

  final String? value;
  final String label;
}

/// База знаний: список материалов, курс, урок и отметка «изучено».
class KnowledgeController extends ChangeNotifier with SafeNotifier {
  KnowledgeController(this._api);

  final ApiClient _api;

  List<Course> courses = const [];
  CourseKindFilter kind = CourseKindFilter.all;
  String query = '';
  bool loading = false;
  bool loaded = false;
  String? error;

  Timer? _debounce;

  /// Растёт при каждой отметке «изучено»: открытый курс по нему понимает,
  /// что галочки пора перечитать — даже если отметили в соседнем уроке.
  int progressVersion = 0;

  /// Номер последней загрузки: опоздавший ответ не затирает свежий.
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    final request = ++_request;

    if (!silent) {
      loading = true;
      notifyListeners();
    }

    final q = query.trim();

    try {
      final response = await _api.get(
        '/courses',
        query: {
          if (kind.value != null) 'kind': kind.value,
          if (q.isNotEmpty) 'q': q,
        },
      );
      if (request != _request) return;

      courses = (response['data'] as List<dynamic>? ?? const [])
          .map((c) => Course.fromJson(c as Map<String, dynamic>))
          .toList();
      loaded = true;
      error = null;
    } on ApiException catch (e) {
      if (request == _request) error = e.message;
    } finally {
      if (request == _request) loading = false;
      notifyListeners();
    }
  }

  void setKind(CourseKindFilter value) {
    kind = value;
    // Набранный поиск уйдёт вместе с фильтром — отдельный запрос не нужен
    _debounce?.cancel();
    unawaited(load(silent: loaded));
  }

  /// Поиск с задержкой: не на каждую букву.
  void search(String value) {
    query = value;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => load(silent: true),
    );
  }

  Future<CourseDetail> course(int id) async {
    final response = await _api.get('/courses/$id');
    return CourseDetail.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Lesson> lesson(int id) async {
    final response = await _api.get('/lessons/$id');
    return Lesson.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Отметить урок изученным или снять отметку. Список с прогрессом
  /// «Пройдено N из M» перечитывается в фоне — кнопка его не ждёт.
  Future<Lesson> mark(int lessonId, {required bool completed}) async {
    final path = '/lessons/$lessonId/complete';
    final response = completed
        ? await _api.post(path)
        : await _api.delete(path);

    final lesson = Lesson.fromJson(response['data'] as Map<String, dynamic>);
    progressVersion++;
    notifyListeners();
    unawaited(load(silent: true));

    return lesson;
  }
}
