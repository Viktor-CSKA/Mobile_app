import 'package:ezhemesyachno/core/widgets/month_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpRing(
    WidgetTester tester, {
    required int paid,
    required int total,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthProgressRing(paidKopecks: paid, totalKopecks: total),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('показывает процент оплаченного', (tester) async {
    await pumpRing(tester, paid: 5000, total: 10000);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('осталось'), findsOneWidget);
  });

  testWidgets('всё оплачено: подпись «всё оплачено» и 100%', (tester) async {
    await pumpRing(tester, paid: 8000, total: 8000);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('всё оплачено'), findsOneWidget);
  });

  testWidgets('ничего не оплачено: 0% и «осталось»', (tester) async {
    await pumpRing(tester, paid: 0, total: 5000);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('осталось'), findsOneWidget);
    expect(find.text('всё оплачено'), findsNothing);
  });

  testWidgets('пустой месяц без платежей не делит на ноль', (tester) async {
    await pumpRing(tester, paid: 0, total: 0);
    expect(find.text('0%'), findsOneWidget);
  });
}
