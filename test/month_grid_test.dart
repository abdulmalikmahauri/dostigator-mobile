import 'package:dostigator/design/theme.dart';
import 'package:dostigator/widgets/d_month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildDostigatorTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU', null);
  });

  testWidgets('месяц начинается с нужного дня недели', (tester) async {
    // 1 ноября 2026 — воскресенье: перед ним шесть пустых клеток
    await tester.pumpWidget(
      _wrap(DMonthGrid(month: DateTime.utc(2026, 11), onSelect: (_) {})),
    );

    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('31'), findsNothing);

    final monday = tester.getTopLeft(find.text('Пн'));
    final sunday = tester.getTopLeft(find.text('Вс'));
    final first = tester.getTopLeft(find.text('1'));
    final second = tester.getTopLeft(find.text('2'));

    expect((first.dx - sunday.dx).abs(), lessThan(24));
    expect((second.dx - monday.dx).abs(), lessThan(24));
  });

  testWidgets('день с событиями объявляется читалке экрана', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        DMonthGrid(
          month: DateTime.utc(2026, 11),
          eventDays: const {12},
          meetingDays: const {12, 19},
          onSelect: (_) {},
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('12 ноября.*мероприятие.*заседание')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('19 ноября.*заседание')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('нажатие выбирает день', (tester) async {
    int? picked;

    await tester.pumpWidget(
      _wrap(
        DMonthGrid(month: DateTime.utc(2026, 11), onSelect: (d) => picked = d),
      ),
    );
    await tester.tap(find.text('17'));

    expect(picked, 17);
  });

  testWidgets('день нажимается и читалкой экрана', (tester) async {
    final handle = tester.ensureSemantics();
    int? picked;

    await tester.pumpWidget(
      _wrap(
        DMonthGrid(month: DateTime.utc(2026, 11), onSelect: (d) => picked = d),
      ),
    );
    tester.semantics.tap(find.semantics.byLabel(RegExp('^18 ноября')));

    expect(picked, 18);
    handle.dispose();
  });
}
