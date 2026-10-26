import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_scheduler.dart';
import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

Future<void> seedOne(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cat = (await repo.watchCategories().first).first.id;
  await repo.add(
    PaymentDraft(
      name: 'Интернет',
      categoryId: cat,
      amountKopecks: 69000,
      nextDueAt: DateTime(2026, 10, 20),
    ),
  );
}

Finder get formTitle => find.widgetWithText(AppBar, 'Платёж');

void main() {
  final s1 = FakeNotificationScheduler();
  appTest(
    'нажатие на напоминание открывает платёж',
    (tester, db) async {
      expect(formTitle, findsNothing);

      s1.tap(1);
      await tester.pumpAndSettle();

      expect(formTitle, findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Интернет'), findsOneWidget);
    },
    today: today,
    seed: seedOne,
    scheduler: s1,
  );

  final s2 = FakeNotificationScheduler()..launchPaymentId = 1;
  appTest(
    'приложение запущено уведомлением: сразу открывается платёж',
    (tester, db) async {
      await tester.pumpAndSettle();

      expect(formTitle, findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Интернет'), findsOneWidget);
    },
    today: today,
    seed: seedOne,
    scheduler: s2,
  );

  final s3 = FakeNotificationScheduler();
  appTest(
    'платёж из уведомления уже удалён: сообщение вместо формы',
    (tester, db) async {
      s3.tap(99);
      await tester.pumpAndSettle();

      expect(formTitle, findsNothing);
      expect(find.text('Этот платёж уже удалён'), findsOneWidget);
    },
    today: today,
    seed: seedOne,
    scheduler: s3,
  );

  final s4 = FakeNotificationScheduler();
  appTest(
    'после закрытия платежа пользователь на вкладке «Ближайшие»',
    (tester, db) async {
      await openTab(tester, 'Настройки');

      s4.tap(1);
      await tester.pumpAndSettle();
      expect(formTitle, findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(formTitle, findsNothing);
      expect(find.widgetWithText(AppBar, 'Ближайшие'), findsOneWidget);
    },
    today: today,
    seed: seedOne,
    scheduler: s4,
  );

  appTest(
    'обычный запуск без уведомления: форма не открывается',
    (tester, db) async {
      await tester.pumpAndSettle();
      expect(formTitle, findsNothing);
    },
    today: today,
    seed: seedOne,
  );
}
