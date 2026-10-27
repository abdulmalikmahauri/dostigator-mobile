import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/directory.dart';

/// Раздел каталога. Клуб — уровень внутри экосистемы, поэтому раздел
/// «Экосистема» показывает всех, а «Бизнес-клуб» — только клубных.
enum ResidentsTier {
  club('club', 'Бизнес-клуб'),
  ecosystem('ecosystem', 'Экосистема');

  const ResidentsTier(this.apiValue, this.title);

  final String apiValue;
  final String title;
}

/// Список резидентов одного раздела: поиск, фильтр по нише, выдача.
/// На каждый открытый раздел — свой экземпляр, чтобы запрос из «Клуба»
/// не всплывал в «Экосистеме».
class ResidentsController extends ChangeNotifier {
  ResidentsController(this._api, this.tier);

  final ApiClient _api;
  final ResidentsTier tier;

  List<DirectoryEntry> residents = const [];
  List<String> niches = const [];

  /// Открыты ли контакты смотрящему — с сервера, вместе со списком.
  bool seesContacts = false;

  bool loading = false;
  String? error;

  String query = '';
  String? niche;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _api.get('/directory', query: _params()),
        _api.get('/directory/filters'),
      ]);

      _applyList(results[0]);

      niches = (results[1]['niches'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList();

      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Map<String, String> _params() {
    final params = <String, String>{'tier': tier.apiValue};

    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (niche != null) params['niche'] = niche!;

    return params;
  }

  void _applyList(Map<String, dynamic> dir) {
    residents = (dir['data'] as List<dynamic>? ?? const [])
        .map((e) => DirectoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = dir['meta'] as Map<String, dynamic>?;
    seesContacts = meta?['sees_contacts'] as bool? ?? seesContacts;
  }

  /// Поиск с задержкой: без неё каждый набранный символ уходит
  /// отдельным запросом, и на медленной сети список скачет.
  void search(String value) {
    query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void filterByNiche(String? value) {
    niche = value;
    _reload();
  }

  Future<void> _reload() async {
    try {
      _applyList(await _api.get('/directory', query: _params()));
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }

    notifyListeners();
  }
}
