import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_scheduler.dart';
import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);
final due = DateTime(2026, 10, 20);

/// Платёж 1 — «Интернет» (690 ₽, 20 октября), платёж 2 — «Электричество»
/// (сумма меняется).
Future<void> seedTwo(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cat = (await repo.watchCategories().first).first.id;
  await repo.add(
    PaymentDraft(
      name: 'Интернет',
      categoryId: cat,
      amountKopecks: 69000,
      nextDueAt: due,
    ),
  );
  await repo.add(
    PaymentDraft(name: 'Электричество', categoryId: cat, nextDueAt: due),
  );
}

Future<void> seedArchived(AppDatabase db) async {
  await seedTwo(db);
  await PaymentsRepository(db).archive(1);
}

Future<Payment> payment(AppDatabase db, int id) async =>
    (await PaymentsRepository(db).getById(id))!;

/// Чтение базы из виджет-теста: только через настоящее время (runAsync).
Future<T> rd<T>(WidgetTester tester, Future<T> Function() read) async =>
    (await tester.runAsync(read)) as T;

Finder get formTitle => find.widgetWithText(AppBar, 'Платёж');

void main() {
  final s1 = FakeNotificationScheduler();
  appTest(
    '«Оплачено» на уведомлении отмечает платёж с известной суммой сразу',
    (tester, db) async {
      s1.tapPaid(1, due: due);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('«Интернет» оплачен. Следующий:'), findsOne);
      final p = await rd(tester, () => payment(db, 1));
      expect(p.nextDueAt, DateTime(2026, 11, 20));
      final records = await rd(
        tester,
        () => PaymentsRepository(db).watchRecords(1).first,
      );
      expect(records.single.amountKopecks, 69000);
    },
    today: today,
    seed: seedTwo,
    scheduler: s1,
  );

  final s2 = FakeNotificationScheduler();
  appTest(
    'у платежа с переменной суммой «Оплачено» спрашивает сумму',
    (tester, db) async {
      s2.tapPaid(2, due: due);
      await tester.pumpAndSettle();

      expect(find.text('Оплачено: Электричество'), findsOneWidget);
      // Пока сумму не ввели, платёж не тронут.
      expect((await rd(tester, () => payment(db, 2))).nextDueAt, due);

      await tester.enterText(find.byType(TextFormField), '1500');
      await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
      await tester.pumpAndSettle();

      final records = await rd(
        tester,
        () => PaymentsRepository(db).watchRecords(2).first,
      );
      expect(records.single.amountKopecks, 150000);
    },
    today: today,
    seed: seedTwo,
    scheduler: s2,
  );

  final s3 = FakeNotificationScheduler();
  appTest(
    'оплату, отмеченную с уведомления, можно отменить',
    (tester, db) async {
      s3.tapPaid(1, due: due);
      await tester.pumpAndSettle();
      expect(
        (await rd(tester, () => payment(db, 1))).nextDueAt,
        DateTime(2026, 11, 20),
      );

      await tester.tap(find.text('Отменить'));
      await tester.pumpAndSettle();

      expect((await rd(tester, () => payment(db, 1))).nextDueAt, due);
      expect(
        await rd(tester, () => PaymentsRepository(db).watchRecords(1).first),
        isEmpty,
      );
    },
    today: today,
    seed: seedTwo,
    scheduler: s3,
  );

  final s4 = FakeNotificationScheduler();
  appTest(
    'устаревшая кнопка (дата платежа уже другая): платёж не отмечается',
    (tester, db) async {
      // Платёж уже оплатили в приложении: ближайшая дата ушла на 20 ноября.
      await tester.runAsync(() => PaymentsRepository(db).markPaid(1));

      s4.tapPaid(1, due: due);
      await tester.pumpAndSettle();

      expect(find.textContaining('уже изменён'), findsOneWidget);
      expect(formTitle, findsOneWidget);
      final records = await rd(
        tester,
        () => PaymentsRepository(db).watchRecords(1).first,
      );
      expect(records.length, 1); // только первая оплата
    },
    today: today,
    seed: seedTwo,
    scheduler: s4,
  );

  final s5 = FakeNotificationScheduler();
  appTest(
    'платёж в архиве: «Оплачено» ничего не отмечает',
    (tester, db) async {
      s5.tapPaid(1, due: due);
      await tester.pumpAndSettle();

      expect(find.textContaining('уже изменён'), findsOneWidget);
      expect(
        await rd(tester, () => PaymentsRepository(db).watchRecords(1).first),
        isEmpty,
      );
    },
    today: today,
    seed: seedArchived,
    scheduler: s5,
  );

  final s6 = FakeNotificationScheduler()
    ..launchPaymentId = 1
    ..launchMarkPaid = true;
  appTest(
    'приложение запущено кнопкой «Оплачено»: платёж отмечен',
    (tester, db) async {
      await tester.pumpAndSettle();

      expect(find.textContaining('«Интернет» оплачен'), findsOne);
      expect(
        (await rd(tester, () => payment(db, 1))).nextDueAt,
        DateTime(2026, 11, 20),
      );
    },
    today: today,
    seed: seedTwo,
    scheduler: s6,
  );

  final s7 = FakeNotificationScheduler();
  appTest(
    'напоминание из прежней версии (без даты) отмечается по кнопке',
    (tester, db) async {
      s7.tapPaid(1);
      await tester.pumpAndSettle();

      expect(
        (await rd(tester, () => payment(db, 1))).nextDueAt,
        DateTime(2026, 11, 20),
      );
    },
    today: today,
    seed: seedTwo,
    scheduler: s7,
  );
}
