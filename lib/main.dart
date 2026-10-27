import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/push/push_channel.dart';
import 'core/push/push_service.dart';
import 'core/reminders.dart';
import 'core/token_storage.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth_controller.dart';
import 'state/session_scope.dart';
import 'state/theme_controller.dart';
import 'design/colors.dart';
import 'design/theme.dart';
import 'widgets/d_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Без этого DateFormat('d MMMM y', 'ru_RU') падает на первом же экране
  await initializeDateFormatting('ru_RU', null);

  // Разрешение здесь НЕ спрашиваем — только готовим службу.
  // Спросим в момент постановки цели, когда польза очевидна.
  // Первый экран её не ждёт: напоминания — не причина держать заставку.
  unawaited(_prepareReminders());

  final tokens = TokenStorage();
  final api = ApiClient(tokens: tokens);

  // Уведомления от сервера есть только в браузере. В приложении на телефоне
  // здесь null — оно напоминает само, средствами телефона. Создаём один раз:
  // служба помнит ключ сервера, и пересоздание его бы теряло
  final push = kIsWeb
      ? PushService(api: api, channel: createPushChannel())
      : null;

  runApp(DostigatorApp(api: api, tokens: tokens, push: push));
}

Future<void> _prepareReminders() async {
  try {
    await Reminders.init();
  } on Exception catch (e) {
    debugPrint('Напоминания недоступны: $e');
  }
}

class DostigatorApp extends StatelessWidget {
  const DostigatorApp({
    super.key,
    required this.api,
    required this.tokens,
    this.push,
  });

  final ApiClient api;
  final TokenStorage tokens;
  final PushService? push;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<PushService?>.value(value: push),
        ChangeNotifierProvider(
          create: (_) =>
              AuthController(api: api, tokens: tokens, push: push)
                ..restoreSession(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController(PrefsThemeStorage())..restore(),
        ),
      ],
      // Цели, события и прочее — свои у каждого входа
      child: SessionScope(
        api: api,
        child: Builder(
          builder: (context) {
            final themeMode = context.watch<ThemeController>().mode;

            return MaterialApp(
              title: 'Достигатор',
              debugShowCheckedModeBanner: false,
              theme: buildDostigatorTheme(palette: DColors.light),
              darkTheme: buildDostigatorTheme(),
              themeMode: themeMode,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const _Root(),
            );
          },
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final stage = context.watch<AuthController>().stage;
    final c = DColors.of(context);

    // Экраны рисуют шапку сами, без AppBar, поэтому цвет значков
    // статус-бара задаём здесь — иначе в светлой теме они пропадут
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: switch (stage) {
        AuthStage.loading => const _Splash(),
        AuthStage.signedIn => const HomeShell(),
        _ => const LoginScreen(),
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DBackground(
        child: Center(
          child: CircularProgressIndicator(color: DColors.of(context).accent),
        ),
      ),
    );
  }
}
