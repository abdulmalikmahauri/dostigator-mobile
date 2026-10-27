import 'package:dostigator/core/api_client.dart';
import 'package:dostigator/screens/event_proposal_screen.dart';
import 'package:dostigator/screens/my_proposals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers/api.dart';
import 'helpers/events.dart';

/// Кнопка отправки — последний элемент прокрутки, её надо докрутить.
Future<void> _submit(WidgetTester tester) async {
  final button = find.text('Отправить организаторам');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  group('Предложить мероприятие', () {
    testWidgets('без названия и даты не отправляется', (tester) async {
      tallWindow(tester);
      final events = StubEventsController(unreachableApi());

      await tester.pumpWidget(
        wrapEvents(const EventProposalScreen(), events: events),
      );
      await _submit(tester);

      expect(find.text('Напишите название'), findsOneWidget);
      expect(find.text('Выберите дату'), findsWidgets);
      expect(events.proposed, isEmpty);
    });

    testWidgets('заполненная форма уходит организаторам', (tester) async {
      tallWindow(tester);
      final events = StubEventsController(unreachableApi());

      await tester.pumpWidget(
        wrapEvents(
          EventProposalScreen(initialDate: DateTime(2099, 3, 14)),
          events: events,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название'),
        'Разбор воронок продаж',
      );
      await tester.tap(find.text('Онлайн'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Сколько мест'),
        '20',
      );
      await _submit(tester);

      final draft = events.proposed.single;
      expect(draft.title, 'Разбор воронок продаж');
      expect(draft.format, 'online');
      expect(draft.capacity, 20);
      // Выбранный день и время по умолчанию — вечер, как у большинства встреч
      expect(draft.startsAt, DateTime.utc(2099, 3, 14, 19));
    });

    testWidgets('замечание сервера видно у своего поля', (tester) async {
      tallWindow(tester);
      final events = StubEventsController(unreachableApi())
        ..proposeError = ApiException(
          'Эта дата уже прошла',
          statusCode: 422,
          fieldErrors: const {
            'starts_at': ['Эта дата уже прошла'],
          },
        );

      await tester.pumpWidget(
        wrapEvents(
          EventProposalScreen(initialDate: DateTime(2099, 3, 14)),
          events: events,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название'),
        'Разбор',
      );
      await _submit(tester);
      await tester.pump();

      expect(find.text('Эта дата уже прошла'), findsWidgets);
    });

    testWidgets('сколько мест — только целое число', (tester) async {
      tallWindow(tester);
      final events = StubEventsController(unreachableApi());

      await tester.pumpWidget(
        wrapEvents(
          EventProposalScreen(initialDate: DateTime(2099, 3, 14)),
          events: events,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Название'),
        'Разбор',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Сколько мест'),
        '0',
      );
      await _submit(tester);

      expect(find.text('От 1 до 10 000'), findsOneWidget);
      expect(events.proposed, isEmpty);
    });
  });

  group('Мои предложения', () {
    testWidgets('статус, причина отказа и отзыв ждущего решения', (
      tester,
    ) async {
      tallWindow(tester);
      final events = StubEventsController(unreachableApi())
        ..proposals = [
          testProposal(id: 4, title: 'Разбор воронок'),
          testProposal(
            id: 5,
            title: 'Поездка в Дагестан',
            status: 'rejected',
            statusLabel: 'Отклонено',
            reason: 'Пересекается с форумом',
          ),
        ];

      await tester.pumpWidget(
        wrapEvents(const MyProposalsScreen(), events: events),
      );
      await tester.pump();

      expect(find.text('На согласовании'), findsOneWidget);
      expect(find.text('Отклонено'), findsOneWidget);
      expect(find.textContaining('Пересекается с форумом'), findsOneWidget);
      // Отозвать можно только то, что ещё не рассмотрели
      expect(find.text('Отозвать'), findsOneWidget);

      await tester.tap(find.text('Отозвать'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Отозвать'));
      await tester.pumpAndSettle();

      expect(events.withdrawn, [4]);
      expect(find.text('Разбор воронок'), findsNothing);
    });

    testWidgets('пустой список зовёт предложить первое', (tester) async {
      final events = StubEventsController(unreachableApi());

      await tester.pumpWidget(
        wrapEvents(const MyProposalsScreen(), events: events),
      );
      await tester.pump();

      expect(find.text('Вы пока ничего не предлагали'), findsOneWidget);
      expect(find.text('Предложить мероприятие'), findsOneWidget);
    });
  });
}
