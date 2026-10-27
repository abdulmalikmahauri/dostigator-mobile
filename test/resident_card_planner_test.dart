import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/directory.dart';
import 'package:dostigator/screens/resident_detail_screen.dart';
import 'package:dostigator/state/auth_controller.dart';
import 'package:dostigator/state/directory_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/api.dart';
import 'helpers/theme.dart';

/// Карточка из списка приходит без задач и привычек — полную
/// экран дозапрашивает сам.
class _Directory extends DirectoryController {
  _Directory(super.api, this.full);

  final DirectoryEntry? full;

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<DirectoryEntry?> fetchEntry(int id) async => full;
}

DirectoryEntry _entry({bool withPlanner = false, bool isMe = false}) =>
    DirectoryEntry.fromJson({
      'id': 7,
      'name': 'Аслан Демидов',
      'is_me': isMe,
      'can_contact': false,
      if (withPlanner) ...{
        'tasks': [
          {'id': 3, 'title': 'Открыть склад в Аргуне', 'due_on': '2026-12-01'},
        ],
        'habits': [
          {
            'id': 4,
            'title': 'Бег по утрам',
            'unit': 'км',
            'target': 5,
            'percent': 86,
          },
          {
            'id': 5,
            'title': 'Читать книги',
            'unit': null,
            'target': 1,
            'percent': null,
          },
        ],
      },
    });

Widget _wrap(Widget child, DirectoryController directory, ApiClient api) {
  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(
        value: AuthController(api: api, tokens: MemoryTokenStorage()),
      ),
      ChangeNotifierProvider<DirectoryController>.value(value: directory),
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
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  testWidgets('в карточке — общие задачи и привычки резидента', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final api = unreachableApi();
    await tester.pumpWidget(
      _wrap(
        ResidentDetailScreen(entry: _entry()),
        _Directory(api, _entry(withPlanner: true)),
        api,
      ),
    );
    await tester.pump();

    expect(find.text('ЗАДАЧИ'), findsOneWidget);
    expect(find.text('Открыть склад в Аргуне'), findsOneWidget);
    expect(find.text('ПРИВЫЧКИ'), findsOneWidget);
    expect(find.text('Бег по утрам'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    // Неделя плана не набралась — процента нет
    expect(find.text('Читать книги'), findsOneWidget);
  });

  testWidgets('на чужую задачу можно пожаловаться', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final (:api, :stub) = stubbedApi(
      (call) => (
        201,
        {
          'data': {'id': 1, 'message': 'Спасибо, организаторы посмотрят'},
        },
      ),
    );
    await tester.pumpWidget(
      _wrap(
        ResidentDetailScreen(entry: _entry()),
        _Directory(api, _entry(withPlanner: true)),
        api,
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Пожаловаться: Открыть склад в Аргуне'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Отправить'));
    await tester.pumpAndSettle();

    expect(stub.calls.single.path, '/reports');
    expect(stub.calls.single.body, {'type': 'task', 'id': 3});
    expect(find.text('Спасибо, организаторы посмотрят'), findsOneWidget);
  });

  testWidgets('на себя жаловаться нечего — кнопки нет', (tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final api = unreachableApi();
    await tester.pumpWidget(
      _wrap(
        ResidentDetailScreen(entry: _entry(isMe: true)),
        _Directory(api, _entry(withPlanner: true, isMe: true)),
        api,
      ),
    );
    await tester.pump();

    expect(find.text('Открыть склад в Аргуне'), findsOneWidget);
    expect(
      find.byTooltip('Пожаловаться: Открыть склад в Аргуне'),
      findsNothing,
    );
  });
}
