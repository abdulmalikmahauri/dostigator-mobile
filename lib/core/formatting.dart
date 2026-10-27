import 'package:intl/intl.dart';

/// Форматирование по-русски. Отдельный модуль, потому что «1 200 000 ₽»
/// и «через 12 дней» встречаются на каждом экране, а собранные вручную
/// строки рано или поздно разъезжаются.
class Fmt {
  const Fmt._();

  static final _number = NumberFormat.decimalPattern('ru_RU');
  static final _date = DateFormat('d MMMM y', 'ru_RU');
  static final _shortDate = DateFormat('d MMM', 'ru_RU');

  /// Полные разряды с пробелами: «6 240 000 ₽», не «6,2 млн».
  /// Так требует раздел 34 спецификации — цифра цели должна совпадать
  /// с тем, что человек видит в своей отчётности, знак в знак.
  static String metric(double value, [String? unit]) {
    final suffix = unit == null || unit.isEmpty ? '' : ' $unit';

    final rounded = value.roundToDouble();
    final text = (value - rounded).abs() < 0.005
        ? _number.format(rounded.toInt())
        : _number.format(value);

    return '$text$suffix';
  }

  static String date(DateTime d) => _date.format(d);

  static String shortDate(DateTime d) => _shortDate.format(d);

  /// Русские окончания: 1 день, 2 дня, 5 дней.
  static String plural(int n, String one, String few, String many) =>
      '$n ${word(n, one, few, many)}';

  /// Только слово в нужной форме — когда число стоит отдельно, крупно.
  static String word(int n, String one, String few, String many) {
    final mod100 = n.abs() % 100;
    final mod10 = n.abs() % 10;

    if (mod100 >= 11 && mod100 <= 14) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  static String daysLeft(int days) {
    if (days < 0) {
      return 'срок вышел ${plural(-days, 'день', 'дня', 'дней')} назад';
    }
    if (days == 0) return 'сегодня последний день';
    return 'осталось ${plural(days, 'день', 'дня', 'дней')}';
  }

  static String weeks(int n) => plural(n, 'неделя', 'недели', 'недель');
}
