import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/mastermind.dart';

class MastermindController extends ChangeNotifier {
  MastermindController(this._api);

  final ApiClient _api;

  MastermindGroup? group;
  MastermindSession? nextSession;
  List<Commitment> myCommitments = const [];

  bool loading = false;
  bool busy = false;

  /// Почему группы нет: не распределили или уровень членства не тот.
  /// Пустой экран без объяснения выглядит как поломка.
  String? unavailableReason;

  String? error;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final response = await _api.get('/mastermind/group');
      final data = response['data'];

      if (data is Map<String, dynamic>) {
        group = MastermindGroup.fromJson(data);
        unavailableReason = null;
        await _loadNextSession();
      } else {
        group = null;
        nextSession = null;
        unavailableReason = response['message'] as String?;
      }

      await _loadCommitments();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadNextSession() async {
    final id = group?.nextSession?.id;

    if (id == null) {
      nextSession = null;

      return;
    }

    nextSession = await loadSession(id);
  }

  /// Деталь встречи — для протокола и ближайшей сессии.
  /// null означает «не удалось получить»: экран сам решает, что показать
  /// (протокол — ошибку с повтором, вкладка — просто без блока повестки).
  Future<MastermindSession?> loadSession(int id) async {
    try {
      final response = await _api.get('/mastermind/sessions/$id');

      return MastermindSession.fromJson(
        response['data'] as Map<String, dynamic>,
      );
    } on ApiException {
      return null;
    }
  }

  Future<void> _loadCommitments() async {
    try {
      final response = await _api.get('/mastermind/commitments');
      final list = response['data'] as List<dynamic>? ?? const [];
      myCommitments = list
          .map((e) => Commitment.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      myCommitments = const [];
    }
  }

  /// Пересобрать повестку. Доступно куратору перед встречей.
  Future<String?> buildAgenda() async {
    final id = group?.nextSession?.id;

    if (id == null) return 'Нет назначенной встречи';

    busy = true;
    notifyListeners();

    try {
      final response = await _api.post('/mastermind/sessions/$id/agenda');
      nextSession = MastermindSession.fromJson(
        response['data'] as Map<String, dynamic>,
      );

      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String?> toggleCommitment(int id) async {
    busy = true;
    notifyListeners();

    try {
      await _api.post('/mastermind/commitments/$id/toggle');
      await _loadCommitments();

      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
