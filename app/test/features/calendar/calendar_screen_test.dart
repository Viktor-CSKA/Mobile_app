import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

/// Октябрь: Интернет (20-го), Кредит (25-го), Электричество просрочено (10-го,
/// сумма меняется), Вода оплачена 12-го. Подписка — в ноябре.
Future<void> seedCalendar(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cat = (await repo.watchCategories().first).first.id;
  PaymentDraft d(String name, DateTime due, int? amount) => PaymentDraft(
    name: name,
    categoryId: cat,
    amountKopecks: amount,
    nextDueAt: due,
  );
  await repo.add(d('Интернет', DateTime(2026, 10, 20), 69000));
  await repo.add(d('Кредит', DateTime(2026, 10, 25), 1200000));
  await repo.add(d('Электричество', DateTime(2026, 10, 10), null));
  await repo.add(d('Подписка', DateTime(2026, 11, 3), 29900));
  final water = await repo.add(d('Вода', DateTime(2026, 10, 12), 40000));
  await repo.markPaid(water, paidAt: DateTime(2026, 10, 12, 18, 30));
}

Finder dayCell(String day) => find.descendant(
  of: find.byKey(const Key('calendar-grid')),
  matching: find.text(day),
);

Future<void> openCalendar(WidgetTester tester) => openTab(tester, 'Календарь');

Future<void> pickDay(WidgetTester tester, String day) async {
  await tester.tap(dayCell(day));
  await tester.pumpAndSettle();
}

void main() {
  appTest('показывает месяц, дни недели и сегодняшний день', (
    tester,
    db,
  ) async {
    await openCalendar(tester);

    expect(find.text('Октябрь 2026'), findsOneWidget);
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    expect(dayCell('31'), findsOneWidget);
    expect(find.text('15 октября 2026 · сегодня'), findsOneWidget);
    expect(find.text('В этот день платежей нет'), findsOneWidget);
  }, today: today);

  appTest(
    'день с платежом показывает его в списке',
    (tester, db) async {
      await openCalendar(tester);
      await pickDay(tester, '20');

      expect(find.text('20 октября 2026'), findsOneWidget);
      expect(find.text('Интернет'), findsOneWidget);
      expect(find.textContaining('через 5 дн.'), findsOneWidget);
      expect(find.textContaining('690'), findsWidgets);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'просроченный платёж помечен',
    (tester, db) async {
      await openCalendar(tester);
      await pickDay(tester, '10');

      expect(find.text('Электричество'), findsOneWidget);
      expect(find.textContaining('просрочено на 5 дн.'), findsOneWidget);
      expect(find.text('сумма меняется'), findsOneWidget);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'оплаченный платёж виден на день оплаты',
    (tester, db) async {
      await openCalendar(tester);
      await pickDay(tester, '12');

      expect(find.text('Вода'), findsOneWidget);
      expect(find.textContaining('Оплачено · ЖКХ'), findsOneWidget);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'итоги месяца: запланировано, переменные суммы, оплачено',
    (tester, db) async {
      await openCalendar(tester);

      expect(find.textContaining('Запланировано: 12 690'), findsOneWidget);
      expect(find.textContaining('+1 с переменной суммой'), findsOneWidget);
      expect(find.textContaining('Оплачено: 400'), findsOneWidget);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'переключение месяцев и возврат на сегодня',
    (tester, db) async {
      await openCalendar(tester);

      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pumpAndSettle();
      expect(find.text('Ноябрь 2026'), findsOneWidget);
      // В ноябре выбран 1-й день; платежи на 3-е (Подписка) и 20-е (Интернет).
      await pickDay(tester, '3');
      expect(find.text('Подписка'), findsOneWidget);
      await pickDay(tester, '20');
      expect(find.text('Интернет'), findsOneWidget);

      await tester.tap(find.byTooltip('Предыдущий месяц'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Предыдущий месяц'));
      await tester.pumpAndSettle();
      expect(find.text('Сентябрь 2026'), findsOneWidget);
      expect(find.text('Запланировано: 0 ₽ · Оплачено: 0 ₽'), findsOneWidget);

      await tester.tap(find.text('Сегодня'));
      await tester.pumpAndSettle();
      expect(find.text('Октябрь 2026'), findsOneWidget);
      expect(find.text('15 октября 2026 · сегодня'), findsOneWidget);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'нажатие на запланированный платёж открывает его форму',
    (tester, db) async {
      await openCalendar(tester);
      await pickDay(tester, '25');

      await tester.tap(find.text('Кредит'));
      await tester.pumpAndSettle();

      expect(find.text('Платёж'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'нажатие на оплаченную запись открывает платёж с историей оплат',
    (tester, db) async {
      await openCalendar(tester);
      await pickDay(tester, '12');

      await tester.tap(find.text('Вода'));
      await tester.pumpAndSettle();

      expect(find.text('Платёж'), findsOneWidget);
      expect(find.text('История оплат'), findsOneWidget);
    },
    today: today,
    seed: seedCalendar,
  );

  appTest(
    'платёж в архиве: прошлые оплаты видны в календаре, будущих нет',
    (tester, db) async {
      await openCalendar(tester);

      // Оплата 12 октября осталась, запланированных платежей воды нет.
      await pickDay(tester, '12');
      expect(find.text('Вода'), findsOneWidget);
      expect(find.textContaining('Оплачено ·'), findsOneWidget);
      expect(find.textContaining('Запланировано: 0'), findsOneWidget);

      await tester.tap(find.byTooltip('Следующий месяц'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Запланировано: 0'), findsOneWidget);
      expect(find.textContaining('Оплачено: 0'), findsOneWidget);
    },
    today: today,
    seed: (db) async {
      final repo = PaymentsRepository(db);
      final cat = (await repo.watchCategories().first).first.id;
      final id = await repo.add(
        PaymentDraft(
          name: 'Вода',
          categoryId: cat,
          amountKopecks: 40000,
          nextDueAt: DateTime(2026, 10, 12),
        ),
      );
      await repo.markPaid(id, paidAt: DateTime(2026, 10, 12, 18, 30));
      await repo.archive(id);
    },
  );
}
