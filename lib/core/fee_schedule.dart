/// Час по Москве, в который приходит напоминание о взносе.
const feeReminderHour = 10;

/// Москва живёт по UTC+3 круглый год — перевода часов там нет.
const _moscowOffsetHours = 3;

/// Моменты показа напоминания о взносе (в UTC): десять утра по Москве
/// в каждый из дней, которые назвал сервер, если этот час ещё впереди.
///
/// Какие дни считать «днями напоминаний» — решает сервер: правило
/// «с 25-го числа, пока не оплачен следующий месяц» живёт там одно
/// на приложение и на рассылку в браузер.
List<DateTime> upcomingFeeMoments(List<String> days, DateTime now) {
  final nowUtc = now.toUtc();
  final moments = <DateTime>[];

  for (final day in days) {
    final date = DateTime.tryParse(day);
    if (date == null) continue;

    final moment = DateTime.utc(
      date.year,
      date.month,
      date.day,
      feeReminderHour - _moscowOffsetHours,
    );

    if (moment.isAfter(nowUtc)) moments.add(moment);
  }

  return moments..sort();
}
