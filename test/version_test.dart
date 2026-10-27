import 'dart:io';

import 'package:dostigator/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Версия на экране профиля — то, что человек диктует организатору,
  /// когда что-то не работает. Однажды она уже отстала от настоящей
  /// на две сборки; этот тест не даёт такому повториться.
  test('версия в профиле совпадает с версией сборки', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+\d+',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(declared, isNotNull, reason: 'в pubspec.yaml не найдена версия');
    expect(ProfileScreen.appVersion, declared);
  });
}
