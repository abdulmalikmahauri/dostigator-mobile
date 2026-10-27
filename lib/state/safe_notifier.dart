import 'package:flutter/foundation.dart';

/// Контроллер, который молчит после закрытия. При выходе из аккаунта
/// контроллеры закрываются, а запрос, начатый до выхода, может вернуться
/// позже — его ответ уже никому не нужен и не должен ронять приложение.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
