/// Геометрия по разделу 6 спецификации.
abstract final class DSpace {
  /// Горизонтальный отступ страницы.
  static const page = 22.0;

  /// Между крупными секциями.
  static const section = 18.0;

  /// Внутренний отступ карточки.
  static const card = 22.0;

  /// Между строками списка.
  static const row = 16.0;

  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class DRadius {
  /// Большая карточка.
  static const cardLarge = 24.0;

  /// Средняя карточка.
  static const card = 20.0;

  static const button = 16.0;
  static const input = 14.0;

  /// Chip — полностью скруглён.
  static const chip = 999.0;
}
