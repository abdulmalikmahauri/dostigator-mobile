import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/directory.dart';

/// Вкладка «Клуб» и карта резидента: сводка по сообществу, партнёрские
/// привилегии и накопитель экономии. Списки резидентов живут отдельно —
/// в [ResidentsController], по одному на раздел.
class DirectoryController extends ChangeNotifier {
  DirectoryController(this._api);

  final ApiClient _api;

  List<Partner> partners = const [];
  Savings savings = Savings.empty;
  ClubStats stats = ClubStats.empty;

  /// Открыты ли контакты. Зависит от уровня членства и приходит с сервера —
  /// приложение это не решает.
  bool seesContacts = false;

  bool loading = false;
  bool _loadedOnce = false;
  String? error;

  bool get hasData => partners.isNotEmpty || !stats.isEmpty;

  /// Сколько всего действующих привилегий — для подписи на карте.
  int get offersCount => partners.fold(0, (sum, p) => sum + p.offers.length);

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _api.get('/directory/summary'),
        _api.get('/partners'),
        _api.get('/partners/savings'),
      ]);

      final summary = results[0];
      seesContacts = summary['sees_contacts'] as bool? ?? false;
      final rawStats = summary['stats'];
      stats = rawStats is Map<String, dynamic>
          ? ClubStats.fromJson(rawStats)
          : ClubStats.empty;

      partners = (results[1]['data'] as List<dynamic>? ?? const [])
          .map((e) => Partner.fromJson(e as Map<String, dynamic>))
          .toList();

      savings = Savings.fromJson(results[2]);

      error = null;
      _loadedOnce = true;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Карту можно открыть с главной, не заходя в «Клуб» — тогда данные
  /// ещё не загружены. Повторная загрузка при каждом открытии не нужна.
  Future<void> ensureLoaded() async {
    if (_loadedOnce || loading) return;
    await load();
  }

  /// Карточка резидента по id — для перехода из привилегии к её хозяину.
  Future<DirectoryEntry?> fetchEntry(int id) async {
    try {
      final res = await _api.get('/directory/$id');
      final data = res['data'];

      return data is Map<String, dynamic>
          ? DirectoryEntry.fromJson(data)
          : null;
    } on ApiException {
      return null;
    }
  }

  /// Отметить, что привилегией воспользовались.
  Future<String?> redeem(int offerId, {int? savedAmount}) async {
    try {
      final response = await _api.post('/partners/offers/$offerId/redeem', {
        if (savedAmount != null) 'saved_amount': savedAmount,
      });

      final s = response['savings'];
      if (s is Map<String, dynamic>) {
        savings = Savings.fromJson(s);
        notifyListeners();
      }

      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
