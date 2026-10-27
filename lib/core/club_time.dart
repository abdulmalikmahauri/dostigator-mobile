/// Клубное время — московское. Москва живёт в UTC+3 круглый год,
/// без перехода на летнее время.
///
/// Время мероприятий сервер присылает «как на стене» в Москве, а приложение
/// хранит его как UTC-дату с московскими часами. «Сейчас» и «сегодня»
/// считаем так же — иначе у резидента в отъезде календарь и проверка
/// «это время уже прошло» разойдутся с клубом.
abstract final class ClubTime {
  static const _moscow = Duration(hours: 3);

  /// Подменяется в тестах.
  static DateTime Function() clock = DateTime.now;

  /// Сейчас по Москве: UTC-дата с московскими часами.
  static DateTime now() => clock().toUtc().add(_moscow);

  /// Сегодняшнее число по Москве, полночь.
  static DateTime today() {
    final n = now();
    return DateTime.utc(n.year, n.month, n.day);
  }
}
