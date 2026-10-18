import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

Future<int> _add(
  PaymentsRepository repo, {
  String name = 'Интернет',
  DateTime? due,
  DateTime? ends,
}) async {
  final cat = (await repo.watchCategories().first).first.id;
  return repo.add(
    PaymentDraft(
      name: name,
      categoryId: cat,
      amountKopecks: 69000,
      nextDueAt: due ?? DateTime(2026, 10, 20),
      endsAt: ends,
    ),
  );
}

Future<void> seedActive(AppDatabase db) async {
  await _add(PaymentsRepository(db));
}

Future<void> seedArchived(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  await repo.archive(await _add(repo, due: DateTime(2026, 9, 20)));
}

/// Рассрочка, которую уже выплатили: платёж закрыт и лежит в архиве.
Future<void> seedFinishedLoan(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final id = await _add(
    repo,
    name: 'Рассрочка',
    due: DateTime(2026, 8, 10),
    ends: DateTime(2026, 8, 10),
  );
  await repo.markPaid(id, paidAt: DateTime(2026, 8, 10, 12));
}

Finder tile(String name) => find.widgetWithText(ListTile, name);

Future<void> openArchive(WidgetTester tester) async {
  await openTab(tester, 'Платежи');
  await tester.tap(find.textContaining('Архив ·'));
  await tester.pumpAndSettle();
}

void main() {
  appTest(
    'в архив можно убрать платёж из его формы',
    (tester, db) async {
      await openTab(tester, 'Платежи');
      await tester.tap(tile('Интернет'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('В архив'));
      await tester.pumpAndSettle();

      expect(find.text('Платёж убран в архив: вкладка «Платежи»'), findsOne);
      expect(tile('Интернет'), findsNothing);
      expect(find.text('Архив · 1'), findsOneWidget);

      await tester.tap(find.text('Архив · 1'));
      await tester.pumpAndSettle();
      expect(tile('Интернет'), findsOneWidget);
    },
    today: today,
    seed: seedActive,
  );

  appTest(
    'у нового платежа и у платежа в архиве кнопки «В архив» нет',
    (tester, db) async {
      await openTab(tester, 'Платежи');
      await tester.tap(find.text('Добавить платёж'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('В архив'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await openArchive(tester);
      await tester.tap(tile('Интернет'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('В архив'), findsNothing);
    },
    today: today,
    seed: seedArchived,
  );

  appTest(
    'платёж из архива не показывается в «Ближайших»',
    (tester, db) async {
      expect(find.text('Интернет'), findsNothing);
      await openTab(tester, 'Платежи');
      expect(find.text('Активных платежей нет.'), findsOneWidget);
      expect(find.text('Архив · 1'), findsOneWidget);
    },
    today: today,
    seed: seedArchived,
  );

  appTest(
    'вернуть из архива: дата сдвигается, платёж снова в списке',
    (tester, db) async {
      await openArchive(tester);
      await tester.tap(tile('Интернет'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Платёж в архиве'), findsOneWidget);

      await tester.tap(find.text('Вернуть из архива'));
      await tester.pumpAndSettle();

      expect(find.text('Платёж вернулся в список'), findsOneWidget);
      expect(find.textContaining('Архив ·'), findsNothing);
      expect(tile('Интернет'), findsOneWidget);
      // Прошлая дата 20 сентября сдвинута на ближайшую: 20 октября.
      expect(find.textContaining('20 окт'), findsOneWidget);
    },
    today: today,
    seed: seedArchived,
  );

  appTest(
    'выплаченная рассрочка: можно открыть историю, вернуть — через даты',
    (tester, db) async {
      await openArchive(tester);
      await tester.tap(tile('Рассрочка'));
      await tester.pumpAndSettle();
      // История оплат сохранена.
      expect(find.text('История оплат'), findsOneWidget);

      await tester.tap(find.text('Вернуть из архива'));
      await tester.pumpAndSettle();

      // Срок закончился: платёж не вернулся, форма просит изменить даты.
      expect(find.textContaining('Срок платежа закончился'), findsOneWidget);
      expect(find.text('Вернуть из архива'), findsNothing);
    },
    today: today,
    seed: seedFinishedLoan,
  );

  appTest(
    'сохранение формы выплаченной рассрочки без «Вернуть» оставляет её в архиве',
    (tester, db) async {
      await openArchive(tester);
      await tester.tap(tile('Рассрочка'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Архив · 1'), findsOneWidget);
      expect(find.text('Активных платежей нет.'), findsOneWidget);
    },
    today: today,
    seed: seedFinishedLoan,
  );
}
