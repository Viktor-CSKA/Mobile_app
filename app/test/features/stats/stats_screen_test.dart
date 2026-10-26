import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/core/format/money.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

/// Оплаты: ЖКХ 1 000 ₽ (янв. 2026) и 500 ₽ (март 2026), Подписки 399 ₽
/// (март 2026) и ЖКХ 2 000 ₽ в прошлом году (2025).
Future<void> seedPaid(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cats = await repo.watchCategories().first;
  Future<int> add(String name, Category cat, int amount) => repo.add(
    PaymentDraft(
      name: name,
      categoryId: cat.id,
      amountKopecks: amount,
      nextDueAt: DateTime(2025, 1, 10),
    ),
  );
  final housing = cats.firstWhere((c) => c.name == 'ЖКХ');
  final subs = cats.firstWhere((c) => c.name == 'Подписки');

  final rent = await add('Квартплата', housing, 100000);
  await repo.markPaid(rent, paidAt: DateTime(2025, 11, 5));
  await repo.markPaid(
    rent,
    amountKopecks: 100000,
    paidAt: DateTime(2026, 1, 12),
  );
  await repo.markPaid(
    rent,
    amountKopecks: 50000,
    paidAt: DateTime(2026, 3, 12),
  );
  final plus = await add('Яндекс Плюс', subs, 39900);
  await repo.markPaid(plus, paidAt: DateTime(2026, 3, 18));
}

/// Один платёж без оплат: «Интернет» 690 ₽.
Future<void> seedUnpaid(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cat = (await repo.watchCategories().first).first;
  await repo.add(
    PaymentDraft(
      name: 'Интернет',
      categoryId: cat.id,
      amountKopecks: 69000,
      nextDueAt: DateTime(2026, 10, 20),
    ),
  );
}

Future<void> openStats(WidgetTester tester) async {
  await openTab(tester, 'Календарь');
  await tester.tap(find.byTooltip('Статистика за год'));
  await tester.pumpAndSettle();
}

void main() {
  appTest(
    'статистика текущего года: итог, месяцы и категории',
    (tester, db) async {
      await openStats(tester);

      expect(find.text('Статистика'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      // 1000 + 500 + 399 = 1 899 ₽, три оплаты.
      expect(
        tester.widget<Text>(find.byKey(const Key('stats-total'))).data,
        formatKopecks(189900),
      );
      expect(find.textContaining('3 оплаты'), findsOneWidget);
      // Месяцы с оплатами: январь и март.
      expect(find.textContaining(formatKopecks(100000)), findsWidgets);
      expect(find.textContaining(formatKopecks(89900)), findsWidgets);
      // Категории: ЖКХ 1 500 ₽ (79 %) и Подписки 399 ₽ (21 %).
      await tester.scrollUntilVisible(find.text('Подписки'), 200);
      expect(find.textContaining('79%'), findsOneWidget);
      expect(find.textContaining('21%'), findsOneWidget);
    },
    today: today,
    seed: seedPaid,
  );

  appTest(
    'переключение года: прошлый год со своими оплатами, будущий пустой',
    (tester, db) async {
      await openStats(tester);

      await tester.tap(find.byTooltip('Предыдущий год'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('stats-total'))).data,
        formatKopecks(100000),
      );

      await tester.tap(find.byTooltip('Следующий год'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Следующий год'));
      await tester.pumpAndSettle();
      expect(find.text('2027'), findsOneWidget);
      expect(find.textContaining('оплат пока нет'), findsOneWidget);
      expect(find.byKey(const Key('stats-total')), findsNothing);
    },
    today: today,
    seed: seedPaid,
  );

  appTest('без оплат: подсказка вместо цифр', (tester, db) async {
    await openStats(tester);
    expect(find.textContaining('За 2026 год оплат пока нет'), findsOneWidget);
    expect(find.textContaining('«Оплачено»'), findsOneWidget);
  }, today: today);

  appTest(
    'новая оплата сразу попадает в статистику',
    (tester, db) async {
      await openStats(tester);
      expect(find.byKey(const Key('stats-total')), findsNothing);

      // Платёж уже есть (его положили до запуска), оплату отмечаем при открытой
      // статистике.
      await tester.runAsync(
        () =>
            PaymentsRepository(db)
                .markPaid(1, paidAt: DateTime(2026, 10, 14, 9)),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('stats-total'))).data,
        formatKopecks(69000),
      );
    },
    today: today,
    seed: seedUnpaid,
  );
}
