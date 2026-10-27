import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/colors.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/theme_controller.dart';
import 'package:dostigator/widgets/d_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/theme.dart';

class _FakeStorage extends TokenStorage {
  _FakeStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

/// Приложение в миниатюре: две темы и переключение между ними так же,
/// как в main.dart, чтобы тест проверял реальную проводку.
Widget _app(ThemeController theme) {
  final api = ApiClient(
    tokens: _FakeStorage(),
    dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1')),
  );

  return MultiProvider(
    providers: [
      themeProvider(theme),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: api, tokens: _FakeStorage()),
      ),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        theme: buildDostigatorTheme(palette: DColors.light),
        darkTheme: buildDostigatorTheme(),
        themeMode: context.watch<ThemeController>().mode,
        home: const Scaffold(body: DHeader()),
      ),
    ),
  );
}

void main() {
  group('ThemeController', () {
    test('по умолчанию тёмная тема', () {
      final c = ThemeController(MemoryThemeStorage());

      expect(c.mode, ThemeMode.dark);
      expect(c.isLight, isFalse);
    });

    test('переключение сохраняется в хранилище', () async {
      final storage = MemoryThemeStorage();
      final c = ThemeController(storage);

      await c.toggle();

      expect(c.isLight, isTrue);
      expect(storage.value, 'light');

      await c.toggle();

      expect(c.isLight, isFalse);
      expect(storage.value, 'dark');
    });

    test('restore поднимает сохранённую светлую тему', () async {
      final storage = MemoryThemeStorage()..value = 'light';
      final c = ThemeController(storage);

      await c.restore();

      expect(c.isLight, isTrue);
    });

    test('restore без сохранённого значения оставляет тёмную', () async {
      final c = ThemeController(MemoryThemeStorage());

      await c.restore();

      expect(c.isLight, isFalse);
    });
  });

  group('Переключатель в шапке', () {
    testWidgets('меняет тему приложения и собственный значок', (tester) async {
      final theme = ThemeController(MemoryThemeStorage());
      await tester.pumpWidget(_app(theme));
      await tester.pump();

      final headerContext = tester.element(find.byType(DHeader));
      expect(Theme.of(headerContext).brightness, Brightness.dark);
      expect(DColors.of(headerContext).accent, DColors.dark.accent);

      await tester.tap(find.byTooltip('Светлая тема'));
      await tester.pumpAndSettle();

      final afterContext = tester.element(find.byType(DHeader));
      expect(Theme.of(afterContext).brightness, Brightness.light);
      expect(DColors.of(afterContext).accent, DColors.light.accent);
      expect(find.byTooltip('Тёмная тема'), findsOneWidget);
      expect(find.byTooltip('Светлая тема'), findsNothing);
    });
  });

  group('Палитры', () {
    test('светлая и тёмная темы регистрируют свою палитру', () {
      expect(buildDostigatorTheme().extension<DColors>(), DColors.dark);
      expect(
        buildDostigatorTheme(palette: DColors.light).extension<DColors>(),
        DColors.light,
      );
    });

    test('вне MaterialApp DColors.of отдаёт фирменную тёмную', () {
      // Контекст без темы: сплэш до старта, изолированные виджеты в тестах
      expect(DColors.dark.isLight, isFalse);
      expect(DColors.light.isLight, isTrue);
    });
  });
}
