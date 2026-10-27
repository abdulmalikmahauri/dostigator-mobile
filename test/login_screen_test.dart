import 'package:dio/dio.dart';
import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/core/token_storage.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/screens/login_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/theme.dart';

/// Хранилище в памяти: настоящее лезет в Android Keystore, которого в тестах нет.
class _FakeStorage extends TokenStorage {
  _FakeStorage() : super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// Сеть в тестах недоступна — важно, что экран это переживает,
/// а не падает с красным экраном.
ApiClient _apiThatFails() {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'));
  return ApiClient(tokens: _FakeStorage(), dio: dio);
}

/// Вход без сети: отвечает то, что велел тест.
class _ScriptedAuth extends AuthController {
  _ScriptedAuth({required this.succeeds})
    : super(api: _apiThatFails(), tokens: _FakeStorage());

  final bool succeeds;

  @override
  Future<bool> signIn(String login, String password) async => succeeds;
}

/// Просил ли экран систему запомнить введённую пару логин–пароль.
bool _askedToSaveCredentials(WidgetTester tester) {
  return tester.testTextInput.log.any(
    (call) =>
        call.method == 'TextInput.finishAutofillContext' &&
        call.arguments == true,
  );
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, '+79000001122');
  await tester.enterText(find.byType(TextField).last, 'Parol-2026');
  await tester.pump();
  await tester.tap(find.text('Войти'));
  await tester.pump();
}

Widget _wrap(Widget child, {AuthController? auth}) {
  final client = _apiThatFails();

  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<AuthController>.value(
        value: auth ?? AuthController(api: client, tokens: _FakeStorage()),
      ),
    ],
    child: MaterialApp(
      theme: buildDostigatorTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  testWidgets('экран входа показывает бренд, поля и кнопку', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();

    expect(find.text('Экосистема резидентов'), findsOneWidget);
    expect(find.text('Вход в приложение'), findsOneWidget);
    expect(find.text('Телефон или e-mail'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Забыли пароль?'), findsOneWidget);
  });

  /// Пустая форма не должна отправляться: запрос заведомо вернёт ошибку
  /// и потратит попытку входа.
  testWidgets('кнопка входа неактивна, пока поля не заполнены', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();

    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Войти'),
    );
    expect(disabled.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '+79000000001');
    await tester.enterText(find.byType(TextField).last, 'пароль123');
    await tester.pump();

    final ready = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Войти'),
    );
    expect(ready.onPressed, isNotNull);
  });

  /// Пароль диктуют по телефону — без возможности его увидеть
  /// вход превращается в лотерею.
  testWidgets('пароль можно показать и снова скрыть', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();

    expect(find.byTooltip('Показать пароль'), findsOneWidget);

    await tester.tap(find.byTooltip('Показать пароль'));
    await tester.pump();

    expect(find.byTooltip('Скрыть пароль'), findsOneWidget);
  });

  /// Сервер отвечает одинаково на незнакомый логин и неверный пароль —
  /// экран показывает это сообщение как есть, не раскрывая наличие аккаунта.
  testWidgets('ошибка входа показывается одним общим сообщением', (
    tester,
  ) async {
    final client = _apiThatFails();
    final auth = AuthController(api: client, tokens: _FakeStorage())
      ..error = 'Неверный логин или пароль';

    await tester.pumpWidget(_wrap(const LoginScreen(), auth: auth));
    await tester.pump();

    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    // Ошибка компактная: без отдельной карточки с кнопкой «Повторить»
    expect(find.text('Повторить'), findsNothing);
  });

  /// Пока запрос идёт, кнопка в loading-состоянии: спиннер вместо текста
  /// и запрет повторного нажатия — иначе уйдут два запроса подряд.
  testWidgets('во время запроса кнопка заблокирована и крутит спиннер', (
    tester,
  ) async {
    final client = _apiThatFails();
    final auth = AuthController(api: client, tokens: _FakeStorage())
      ..busy = true;

    await tester.pumpWidget(_wrap(const LoginScreen(), auth: auth));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  group('Сохранение пароля в телефоне', () {
    /// Без общей группы телефон не понимает, что логин и пароль —
    /// одна пара, и запомнить их не предлагает.
    testWidgets('логин и пароль объединены в одну группу', (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      final group = find.byType(AutofillGroup);

      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.byType(TextField)),
        findsNWidgets(2),
      );
    });

    testWidgets('после удачного входа системе предлагают их запомнить', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LoginScreen(), auth: _ScriptedAuth(succeeds: true)),
      );

      await _signIn(tester);

      expect(_askedToSaveCredentials(tester), isTrue);
    });

    /// Неверный пароль запоминать незачем: он подставлялся бы снова и снова.
    testWidgets('после неудачного входа запомнить не предлагают', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const LoginScreen(), auth: _ScriptedAuth(succeeds: false)),
      );

      await _signIn(tester);

      expect(_askedToSaveCredentials(tester), isFalse);
    });
  });

  /// Автоматического сброса пароля нет — «Забыли пароль?» ведёт
  /// к контакту организатора клуба с возможностью скопировать номер.
  testWidgets('«Забыли пароль?» открывает диалог с телефоном организатора', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();

    await tester.tap(find.text('Забыли пароль?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Обратитесь к организатору'), findsOneWidget);
    expect(find.text('+7 900 000 00 01'), findsOneWidget);
    expect(find.text('Скопировать номер'), findsOneWidget);

    // Копирование закрывает диалог и подтверждает действие снекбаром
    await tester.tap(find.text('Скопировать номер'));
    await tester.pumpAndSettle();

    expect(find.text('+7 900 000 00 01'), findsNothing);
    expect(find.text('Номер скопирован'), findsOneWidget);
  });
}
