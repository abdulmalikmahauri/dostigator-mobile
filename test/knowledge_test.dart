import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/design/theme.dart';
import 'package:dostigator/models/knowledge.dart';
import 'package:dostigator/screens/course_screen.dart';
import 'package:dostigator/screens/knowledge_screen.dart';
import 'package:dostigator/screens/lesson_screen.dart';
import 'package:dostigator/state/knowledge_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/api.dart';
import 'helpers/theme.dart';

Map<String, dynamic> _courseJson({
  int id = 1,
  String kind = 'course',
  String kindLabel = 'Курс',
  String title = 'Финансы для собственника',
  int lessons = 5,
  int completed = 2,
  bool available = true,
  int? firstLessonId,
}) => {
  'id': id,
  'kind': kind,
  'kind_label': kindLabel,
  'title': title,
  'description': 'Как читать отчёты и не терять деньги',
  'cover_url': null,
  'lessons_count': lessons,
  'duration_minutes': 75,
  'completed_count': completed,
  'is_available': available,
  'min_tier_label': available ? null : 'Бизнес-клуб',
  'first_lesson_id': firstLessonId,
};

Map<String, dynamic> _lessonJson({
  bool available = true,
  bool completed = false,
  bool video = true,
  int? nextId = 12,
}) => {
  'id': 11,
  'course_id': 1,
  'course_title': 'Финансы для собственника',
  'course_kind_label': 'Курс',
  'title': 'Отчёт о прибылях',
  'duration_minutes': 15,
  'number': 1,
  'total': 5,
  'is_available': available,
  'min_tier_label': available ? null : 'Бизнес-клуб',
  'body': available ? 'Первый абзац.\n\nВторой абзац.' : null,
  'video': available && video
      ? {
          'provider': 'rutube',
          'provider_label': 'Rutube',
          'embed_url': 'https://rutube.ru/play/embed/abc',
          'watch_url': 'https://rutube.ru/video/abc/',
        }
      : null,
  'is_completed': completed,
  'prev_id': null,
  'next_id': nextId,
};

/// Без сети: экран берёт данные, которые положил тест,
/// и записывает, что его попросили сделать.
class _StubKnowledge extends KnowledgeController {
  _StubKnowledge(super.api);

  CourseDetail? detailResult;
  Lesson? lessonResult;
  final List<(int, bool)> marked = [];

  @override
  Future<void> load({bool silent = false}) async {}

  @override
  Future<CourseDetail> course(int id) async => detailResult!;

  @override
  Future<Lesson> lesson(int id) async => lessonResult!;

  @override
  Future<Lesson> mark(int lessonId, {required bool completed}) async {
    marked.add((lessonId, completed));
    return Lesson.fromJson(_lessonJson(completed: completed));
  }
}

Widget _wrap(Widget child, KnowledgeController c, ApiClient api) {
  return MultiProvider(
    providers: [
      themeProvider(),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<KnowledgeController>.value(value: c),
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

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Данные', () {
    test('материал: прогресс и длительность', () {
      final c = Course.fromJson(_courseJson());

      expect(c.kindLabel, 'Курс');
      expect(c.progressLabel, 'Пройдено 2 из 5');
      expect(c.metaLabel, '5 уроков · 1 ч 15 мин');
    });

    test('урок: видео, абзацы и соседние уроки', () {
      final l = Lesson.fromJson(_lessonJson());

      expect(l.video?.providerLabel, 'Rutube');
      expect(l.paragraphs, ['Первый абзац.', 'Второй абзац.']);
      expect(l.nextId, 12);
      expect(l.prevId, isNull);
    });

    test('список грузится с фильтром вида и поиском', () async {
      final (:api, :stub) = stubbedApi(
        (call) => (
          200,
          {
            'data': [_courseJson()],
          },
        ),
      );
      final c = KnowledgeController(api);

      c.setKind(CourseKindFilter.lecture);
      await c.load();

      expect(c.courses.single.title, 'Финансы для собственника');
      expect(stub.calls.last.query['kind'], 'lecture');
    });

    test('отметка «изучено» обновляет прогресс в списке', () async {
      final (:api, stub: _) = stubbedApi((call) {
        if (call.path == '/lessons/11/complete') {
          return (200, {'data': _lessonJson(completed: true)});
        }
        return (
          200,
          {
            'data': [_courseJson(completed: 3)],
          },
        );
      });
      final c = KnowledgeController(api);

      final lesson = await c.mark(11, completed: true);
      expect(lesson.isCompleted, isTrue);

      // Список перечитывается в фоне — дожидаемся
      for (var i = 0; i < 50 && c.courses.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.courses.single.completedCount, 3);
    });
  });

  group('Экраны', () {
    testWidgets('список: вид, название, прогресс и закрытое', (tester) async {
      _tall(tester);
      final api = unreachableApi();
      final c = _StubKnowledge(api)
        ..courses = [
          Course.fromJson(_courseJson()),
          Course.fromJson(
            _courseJson(
              id: 2,
              kind: 'masterclass',
              kindLabel: 'Мастер-класс',
              title: 'Продажи в нише',
              available: false,
            ),
          ),
        ]
        ..loaded = true;

      await tester.pumpWidget(_wrap(const KnowledgeScreen(), c, api));
      await tester.pump();

      expect(find.text('База знаний'), findsOneWidget);
      expect(find.text('Финансы для собственника'), findsOneWidget);
      expect(find.text('Пройдено 2 из 5'), findsOneWidget);
      expect(find.text('Только для бизнес-клуба'), findsOneWidget);
      for (final kind in ['Курсы', 'Лекции', 'Мастер-классы']) {
        expect(find.text(kind), findsOneWidget);
      }
    });

    testWidgets('курс: уроки по порядку с отметкой изученного', (tester) async {
      _tall(tester);
      final api = unreachableApi();
      final c = _StubKnowledge(api)
        ..detailResult = CourseDetail.fromJson({
          ..._courseJson(),
          'lessons': [
            {
              'id': 11,
              'title': 'Отчёт о прибылях',
              'duration_minutes': 15,
              'has_video': true,
              'is_completed': true,
            },
            {
              'id': 12,
              'title': 'Денежный поток',
              'duration_minutes': null,
              'has_video': false,
              'is_completed': false,
            },
          ],
        });

      await tester.pumpWidget(_wrap(const CourseScreen(courseId: 1), c, api));
      await tester.pump();

      expect(find.text('Отчёт о прибылях'), findsOneWidget);
      expect(find.text('Денежный поток'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Изучено')), findsOneWidget);
    });

    testWidgets('урок: видео по нажатию, ссылка на сайт и отметка', (
      tester,
    ) async {
      _tall(tester);
      final api = unreachableApi();
      final c = _StubKnowledge(api)
        ..lessonResult = Lesson.fromJson(_lessonJson());

      await tester.pumpWidget(_wrap(const LessonScreen(lessonId: 11), c, api));
      await tester.pump();

      expect(find.text('Отчёт о прибылях'), findsOneWidget);
      expect(find.text('Смотреть видео'), findsOneWidget);
      expect(find.text('Открыть в Rutube'), findsOneWidget);
      expect(find.text('Второй абзац.'), findsOneWidget);
      expect(find.text('Следующий урок'), findsOneWidget);

      final button = find.text('Отметить как изученное');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(c.marked, [(11, true)]);
      expect(find.text('Изучено'), findsOneWidget);
    });

    testWidgets('видео не с VK и не с Rutube не встраивается', (tester) async {
      _tall(tester);
      final api = unreachableApi();
      final json = _lessonJson();
      (json['video'] as Map<String, dynamic>)['embed_url'] =
          'https://evil.example/embed';
      final c = _StubKnowledge(api)..lessonResult = Lesson.fromJson(json);

      await tester.pumpWidget(_wrap(const LessonScreen(lessonId: 11), c, api));
      await tester.pump();

      expect(find.text('Смотреть видео'), findsNothing);
      expect(find.text('Второй абзац.'), findsOneWidget);
    });

    testWidgets('закрытый урок: ни видео, ни текста, честная причина', (
      tester,
    ) async {
      _tall(tester);
      final api = unreachableApi();
      final c = _StubKnowledge(api)
        ..lessonResult = Lesson.fromJson(_lessonJson(available: false));

      await tester.pumpWidget(_wrap(const LessonScreen(lessonId: 11), c, api));
      await tester.pump();

      expect(find.text('Смотреть видео'), findsNothing);
      expect(find.text('Отметить как изученное'), findsNothing);
      expect(find.textContaining('бизнес-клуба'), findsWidgets);
    });
  });
}
