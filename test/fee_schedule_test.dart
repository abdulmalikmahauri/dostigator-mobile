import 'package:dostigator/core/fee_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Сервер называет дни, приложение превращает их в моменты показа:
  // десять утра по Москве, то есть семь утра по UTC.
  const days = ['2026-10-25', '2026-10-26', '2026-10-27'];

  test('каждый день превращается в десять утра по Москве', () {
    final moments = upcomingFeeMoments(days, DateTime.utc(2026, 10, 13, 12));

    expect(moments, [
      DateTime.utc(2026, 10, 25, 7),
      DateTime.utc(2026, 10, 26, 7),
      DateTime.utc(2026, 10, 27, 7),
    ]);
  });

  test('сегодняшнее напоминание ставится, пока десять утра не прошло', () {
    final before = upcomingFeeMoments(days, DateTime.utc(2026, 10, 25, 6, 59));
    final after = upcomingFeeMoments(days, DateTime.utc(2026, 10, 25, 7, 1));

    expect(before.first, DateTime.utc(2026, 10, 25, 7));
    expect(after.first, DateTime.utc(2026, 10, 26, 7));
  });

  test('прошедшие дни и мусор в списке пропускаются', () {
    final moments = upcomingFeeMoments([
      '2026-10-20',
      'не дата',
      '2026-10-31',
    ], DateTime.utc(2026, 10, 28));

    expect(moments, [DateTime.utc(2026, 10, 31, 7)]);
  });

  test('без дней напоминать не о чем', () {
    expect(upcomingFeeMoments(const [], DateTime.utc(2026, 10, 13)), isEmpty);
  });
}
