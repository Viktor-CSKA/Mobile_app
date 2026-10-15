import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/payments/presentation/payment_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

Future<int> addPayment(
  PaymentsRepository repo, {
  String name = 'Интернет',
  int? amount = 69000,
  DateTime? due,
}) async {
  final cat = (await repo.watchCategories().first).first.id;
  return repo.add(
    PaymentDraft(
      name: name,
      categoryId: cat,
      amountKopecks: amount,
      nextDueAt: due ?? DateTime(2026, 10, 20),
    ),
  );
}

Future<void> seedOne(AppDatabase db) async {
  await addPayment(PaymentsRepository(db));
}

/// Платёж с тремя оплатами разной суммы (для истории).
Future<void> seedWithHistory(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final id = await addPayment(repo, due: DateTime(2026, 8, 20));
  await repo.markPaid(id, paidAt: DateTime(2026, 8, 18, 10));
  await repo.markPaid(
    id,
    amountKopecks: 71500,
    paidAt: DateTime(2026, 9, 21, 12),
  );
  await repo.markPaid(id, paidAt: DateTime(2026, 10, 14, 8));
}

Future<void> seedManyRecords(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final id = await addPayment(repo, due: DateTime(2025, 1, 10));
  for (var i = 0; i < 13; i++) {
    await repo.markPaid(id, paidAt: DateTime(2025, 1 + i, 10));
  }
}

Finder payButton(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.byTooltip('Оплачено'),
);

Future<void> pay(WidgetTester tester, String name) async {
  await tester.tap(payButton(name));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
  await tester.pumpAndSettle();
}

Future<void> openEdit(WidgetTester tester, String name) async {
  await openTab(tester, 'Платежи');
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  group('отмена оплаты', () {
    appTest(
      'сообщение с «Отменить» исчезает само через несколько секунд',
      (tester, db) async {
        await pay(tester, 'Интернет');
        expect(find.text('Отменить'), findsOneWidget);

        await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();

        expect(find.text('Отменить'), findsNothing);
        expect(find.textContaining('оплачен.'), findsNothing);
      },
      today: today,
      seed: seedOne,
    );
    appTest(
      'после «Оплачено» в сообщении есть «Отменить»',
      (tester, db) async {
        await pay(tester, 'Интернет');

        expect(
          find.textContaining('«Интернет» оплачен. Следующий: 20 ноя.'),
          findsOneWidget,
        );
        expect(find.text('Отменить'), findsOneWidget);
      },
      today: today,
      seed: seedOne,
    );

    appTest(
      '«Отменить» возвращает платёж на прежнюю дату',
      (tester, db) async {
        expect(find.textContaining('через 5 дн.'), findsOneWidget);
        await pay(tester, 'Интернет');
        expect(find.textContaining('через 36 дн.'), findsOneWidget);

        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();

        expect(find.textContaining('через 5 дн.'), findsOneWidget);
        expect(find.textContaining('через 36 дн.'), findsNothing);
        expect(find.text('Оплата «Интернет» отменена'), findsOneWidget);
      },
      today: today,
      seed: seedOne,
    );

    appTest(
      'отменённая оплата исчезает из истории платежа',
      (tester, db) async {
        await pay(tester, 'Интернет');
        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();

        await openEdit(tester, 'Интернет');
        expect(find.textContaining('Оплат пока не было'), findsOneWidget);
      },
      today: today,
      seed: seedOne,
    );

    appTest(
      'отмена возвращает завершённую рассрочку в список',
      (tester, db) async {
        await pay(tester, 'Рассрочка');
        expect(find.widgetWithText(ListTile, 'Рассрочка'), findsNothing);

        await tester.tap(find.text('Отменить'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ListTile, 'Рассрочка'), findsOneWidget);
      },
      today: today,
      seed: (db) async {
        final repo = PaymentsRepository(db);
        final cat = (await repo.watchCategories().first).first.id;
        await repo.add(
          PaymentDraft(
            name: 'Рассрочка',
            categoryId: cat,
            amountKopecks: 500000,
            nextDueAt: DateTime(2026, 10, 18),
            endsAt: DateTime(2026, 10, 18),
          ),
        );
      },
    );
  });

  group('история оплат в форме платежа', () {
    appTest(
      'показывает итог и оплаты, новые сверху',
      (tester, db) async {
        await openEdit(tester, 'Интернет');

        expect(find.text('История оплат'), findsOneWidget);
        expect(find.textContaining('Всего оплачено: 2 095'), findsOneWidget);
        expect(find.textContaining('3 оплаты'), findsOneWidget);

        final newest = tester.getTopLeft(find.text('14 октября 2026')).dy;
        final middle = tester.getTopLeft(find.text('21 сентября 2026')).dy;
        final oldest = tester.getTopLeft(find.text('18 августа 2026')).dy;
        expect(newest, lessThan(middle));
        expect(middle, lessThan(oldest));
        expect(find.text('715 ₽'), findsOneWidget); // фактическая сумма оплаты
      },
      today: today,
      seed: seedWithHistory,
    );

    appTest(
      'без оплат — подсказка',
      (tester, db) async {
        await openEdit(tester, 'Интернет');
        expect(find.text('История оплат'), findsOneWidget);
        expect(find.textContaining('Оплат пока не было'), findsOneWidget);
      },
      today: today,
      seed: seedOne,
    );

    appTest('в новой форме истории нет', (tester, db) async {
      await openTab(tester, 'Платежи');
      await tester.tap(find.text('Добавить платёж'));
      await tester.pumpAndSettle();
      expect(find.text('История оплат'), findsNothing);
    }, today: today);

    appTest(
      'длинная история обрезается, итог считает все оплаты',
      (tester, db) async {
        await openEdit(tester, 'Интернет');

        expect(find.textContaining('13 оплат'), findsOneWidget);
        expect(find.text('Показаны последние 12'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(PaymentHistory),
            matching: find.byIcon(Icons.check_circle_outline),
          ),
          findsNWidgets(12),
        );
      },
      today: today,
      seed: seedManyRecords,
    );

    appTest(
      'новая оплата сразу появляется в открытой истории',
      (tester, db) async {
        await pay(tester, 'Интернет');
        await tester.tap(find.text('Отменить')); // убираем сообщение
        await tester.pumpAndSettle();
        await pay(tester, 'Интернет');

        await openEdit(tester, 'Интернет');
        expect(find.textContaining('1 оплата'), findsOneWidget);
      },
      today: today,
      seed: seedOne,
    );
  });

  group('historyTotals', () {
    PaymentRecord r(int id, int amount) => PaymentRecord(
      id: id,
      paymentId: 1,
      amountKopecks: amount,
      paidAt: DateTime(2026, 1, id),
    );

    test('сумма и количество', () {
      final t = historyTotals([r(1, 10000), r(2, 25050)]);
      expect(t.count, 2);
      expect(t.totalKopecks, 35050);
    });

    test('пусто', () {
      final t = historyTotals(const []);
      expect(t.count, 0);
      expect(t.totalKopecks, 0);
    });
  });
}
