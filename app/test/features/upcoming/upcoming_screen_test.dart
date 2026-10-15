import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

/// Платежи для проверки: один просрочен (переменная сумма), три впереди.
Future<void> seedPayments(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cat = (await repo.watchCategories().first).first.id;
  PaymentDraft d(String name, DateTime due, int? amount, {DateTime? ends}) =>
      PaymentDraft(
        name: name,
        categoryId: cat,
        amountKopecks: amount,
        nextDueAt: due,
        endsAt: ends,
      );
  await repo.add(d('Интернет', DateTime(2026, 10, 20), 69000));
  await repo.add(d('Электричество', DateTime(2026, 10, 10), null));
  await repo.add(d('Кредит', DateTime(2026, 10, 25), 1200000));
  await repo.add(d('Подписка', DateTime(2026, 11, 3), 29900));
}

Finder payButton(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.byTooltip('Оплачено'),
);

double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

/// Данные уже в базе (см. `seed:` у appTest); ждём, пока экран их покажет.
Future<void> seed(WidgetTester tester, AppDatabase db) =>
    tester.pumpAndSettle();

Future<void> seedInstallment(AppDatabase db) async {
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
}

void main() {
  appTest('без платежей показывает подсказку', (tester, db) async {
    expect(find.textContaining('Платежей пока нет'), findsOneWidget);
    expect(find.text('Нужно в этом месяце'), findsNothing);
  }, today: today);

  appTest(
    'сумма на месяц: просрочка и остаток месяца, без следующего',
    (tester, db) async {
      await seed(tester, db);

      expect(find.text('Нужно в этом месяце'), findsOneWidget);
      // 690 ₽ + 12 000 ₽ = 12 690 ₽; электричество без суммы, Подписка — в ноябре.
      expect(find.textContaining('12 690'), findsOneWidget);
      expect(find.textContaining('К оплате: 3 платежа'), findsOneWidget);
      expect(
        find.textContaining('и ещё 1 с переменной суммой'),
        findsOneWidget,
      );
      expect(find.textContaining('Просрочено: 1 платёж'), findsOneWidget);
    },
    today: today,
    seed: seedPayments,
  );

  appTest(
    'просроченные сверху, затем по датам, с подписями дней',
    (tester, db) async {
      await seed(tester, db);

      final header = top(tester, find.text('Просрочено'));
      final overdue = top(tester, find.text('Электричество'));
      final internet = top(tester, find.text('Интернет'));
      final loan = top(tester, find.text('Кредит'));
      final sub = top(tester, find.text('Подписка'));
      expect(header, lessThan(overdue));
      expect(overdue, lessThan(internet));
      expect(internet, lessThan(loan));
      expect(loan, lessThan(sub));

      expect(find.textContaining('просрочено на 5 дн.'), findsOneWidget);
      expect(find.textContaining('через 5 дн.'), findsOneWidget);
      expect(find.text('сумма меняется'), findsOneWidget);
    },
    today: today,
    seed: seedPayments,
  );

  appTest(
    '«Оплачено» с известной суммой: сдвигает дату и пересчитывает сумму',
    (tester, db) async {
      await seed(tester, db);

      await tester.tap(payButton('Интернет'));
      await tester.pumpAndSettle();
      expect(find.text('Оплачено: Интернет'), findsOneWidget);
      expect(find.text('690'), findsOneWidget); // сумма подставлена

      await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('«Интернет» оплачен. Следующий: 20 ноя.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.textContaining('12\u00A0000'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('К оплате: 2 платежа'), findsOneWidget);
      // Теперь Интернет (20 ноя) ниже Подписки (3 ноя).
      expect(
        top(tester, find.text('Подписка')),
        lessThan(top(tester, find.text('Интернет'))),
      );
    },
    today: today,
    seed: seedPayments,
  );

  appTest(
    '«Оплачено» с переменной суммой требует ввести сумму',
    (tester, db) async {
      await seed(tester, db);

      await tester.tap(payButton('Электричество'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
      await tester.pumpAndSettle();
      expect(find.text('Введите сумму'), findsOneWidget);
      expect(find.text('Оплачено: Электричество'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '1 234,50');
      await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
      await tester.pumpAndSettle();

      expect(find.text('Просрочено'), findsNothing);
      expect(
        find.textContaining('«Электричество» оплачен. Следующий: 10 ноя.'),
        findsOneWidget,
      );

      final records = await tester.runAsync(() async {
        final repo = PaymentsRepository(db);
        final all = await repo.watchActive().first;
        final id = all
            .firstWhere((e) => e.payment.name == 'Электричество')
            .payment
            .id;
        return repo.watchRecords(id).first;
      });
      expect(records!.single.amountKopecks, 123450);
    },
    today: today,
    seed: seedPayments,
  );

  appTest(
    'отмена в диалоге ничего не меняет',
    (tester, db) async {
      await seed(tester, db);

      await tester.tap(payButton('Интернет'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.textContaining('оплачен.'), findsNothing);
      expect(find.textContaining('через 5 дн.'), findsOneWidget);
    },
    today: today,
    seed: seedPayments,
  );

  appTest(
    'последний платёж по рассрочке убирает её из списка',
    (tester, db) async {
      await tester.pumpAndSettle();

      await tester.tap(payButton('Рассрочка'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('«Рассрочка» оплачен. Платёж завершён.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ListTile, 'Рассрочка'), findsNothing);
      expect(find.textContaining('Платежей пока нет'), findsOneWidget);
    },
    today: today,
    seed: seedInstallment,
  );
}
