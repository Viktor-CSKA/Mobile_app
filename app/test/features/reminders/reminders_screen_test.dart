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

void main() {
  group('синхронизация с платежами', () {
    final scheduler = FakeNotificationScheduler();

    appTest(
      'при запуске планирует напоминания по платежам',
      (tester, db) async {
        await tester.pumpAndSettle();

        expect(scheduler.replaceCalls, isNotEmpty);
        final first = scheduler.lastPlan.first;
        expect(first.title, 'Интернет');
        expect(first.fireAt, DateTime(2026, 10, 19, 9));
      },
      today: today,
      seed: seedOne,
      scheduler: scheduler,
    );

    final scheduler2 = FakeNotificationScheduler();
    appTest(
      'новый платёж через форму добавляет напоминание',
      (tester, db) async {
        await openTab(tester, 'Платежи');
        await tester.tap(find.text('Добавить платёж'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'Кинопоиск',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Сумма'),
          '299',
        );
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        expect(scheduler2.lastPlan.map((e) => e.title), contains('Кинопоиск'));
      },
      today: today,
      scheduler: scheduler2,
    );

    final scheduler3 = FakeNotificationScheduler();
    appTest(
      'отметка «Оплачено» пересчитывает напоминания',
      (tester, db) async {
        await tester.pumpAndSettle();
        expect(scheduler3.lastPlan.first.dueDate, DateTime(2026, 10, 20));

        await tester.tap(find.byTooltip('Оплачено'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Оплачено'));
        await tester.pumpAndSettle();

        // Теперь ближайший платёж — 20 ноября.
        expect(scheduler3.lastPlan.first.dueDate, DateTime(2026, 11, 20));
      },
      today: today,
      seed: seedOne,
      scheduler: scheduler3,
    );

    final scheduler4 = FakeNotificationScheduler();
    appTest(
      'удаление платежа убирает его напоминания',
      (tester, db) async {
        await openTab(tester, 'Платежи');
        await tester.tap(find.text('Интернет'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Удалить'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
        await tester.pumpAndSettle();

        expect(scheduler4.lastPlan, isEmpty);
      },
      today: today,
      seed: seedOne,
      scheduler: scheduler4,
    );
  });

  group('разрешение на уведомления', () {
    final s1 = FakeNotificationScheduler();
    appTest(
      'запрашивается после добавления платежа',
      (tester, db) async {
        await openTab(tester, 'Платежи');
        await tester.tap(find.text('Добавить платёж'));
        await tester.pumpAndSettle();
        expect(s1.permissionRequests, 0);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'Кино',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Сумма'),
          '100',
        );
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        expect(s1.permissionRequests, 1);
      },
      today: today,
      scheduler: s1,
    );

    final s2 = FakeNotificationScheduler();
    appTest(
      'не запрашивается при правке существующего платежа',
      (tester, db) async {
        await openTab(tester, 'Платежи');
        await tester.tap(find.text('Интернет'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        expect(s2.permissionRequests, 0);
      },
      today: today,
      seed: seedOne,
      scheduler: s2,
    );

    final s3 = FakeNotificationScheduler();
    appTest(
      'не запрашивается, если напоминания выключены',
      (tester, db) async {
        await openTab(tester, 'Платежи');
        await tester.tap(find.text('Добавить платёж'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'Кино',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Сумма'),
          '100',
        );
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        expect(s3.permissionRequests, 0);
      },
      today: today,
      scheduler: s3,
      prefs: {'reminders_enabled': false},
    );

    final s4 = FakeNotificationScheduler(notificationsGranted: false);
    appTest(
      'отказ в разрешении не мешает сохранить платёж',
      (tester, db) async {
        await openTab(tester, 'Платежи');
        await tester.tap(find.text('Добавить платёж'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Название'),
          'Кино',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Сумма'),
          '100',
        );
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();

        expect(find.text('Кино'), findsOneWidget);
        expect(find.text('Новый платёж'), findsNothing);
      },
      today: today,
      scheduler: s4,
    );
  });

  group('экран настроек', () {
    final a = FakeNotificationScheduler();
    appTest(
      'показывает время и включённое состояние',
      (tester, db) async {
        await openTab(tester, 'Настройки');

        expect(find.text('Напоминать о платежах'), findsOneWidget);
        expect(find.text('09:00'), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
        expect(find.text('Уведомления выключены'), findsNothing);
        expect(find.text('Точное время выключено'), findsNothing);
      },
      today: today,
      scheduler: a,
    );

    final b = FakeNotificationScheduler();
    appTest(
      'выключатель отменяет напоминания и запоминает выбор',
      (tester, db) async {
        await openTab(tester, 'Настройки');
        final before = b.cancelAllCalls;

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(b.cancelAllCalls, greaterThan(before));
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
      },
      today: today,
      seed: seedOne,
      scheduler: b,
    );

    final c = FakeNotificationScheduler();
    appTest(
      'повторное включение снова планирует напоминания',
      (tester, db) async {
        await openTab(tester, 'Настройки');
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        final plans = c.replaceCalls.length;

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(c.replaceCalls.length, greaterThan(plans));
        expect(c.lastPlan, isNotEmpty);
      },
      today: today,
      seed: seedOne,
      scheduler: c,
    );

    final d = FakeNotificationScheduler(notificationsGranted: false);
    appTest(
      'при запрете уведомлений предлагает разрешить',
      (tester, db) async {
        await openTab(tester, 'Настройки');

        expect(find.text('Уведомления выключены'), findsOneWidget);
        await tester.tap(find.text('Уведомления выключены'));
        await tester.pumpAndSettle();

        expect(d.permissionRequests, 1);
      },
      today: today,
      scheduler: d,
    );

    final e = FakeNotificationScheduler(exactGranted: false);
    appTest(
      'без точных будильников предлагает включить их',
      (tester, db) async {
        await openTab(tester, 'Настройки');

        expect(find.text('Точное время выключено'), findsOneWidget);
        await tester.tap(find.text('Точное время выключено'));
        await tester.pumpAndSettle();

        expect(e.exactRequests, 1);
      },
      today: today,
      scheduler: e,
    );

    final f = FakeNotificationScheduler();
    appTest(
      'проверка уведомления планирует тест через 10 секунд',
      (tester, db) async {
        await openTab(tester, 'Настройки');
        await tester.tap(find.text('Проверить уведомление'));
        await tester.pumpAndSettle();

        expect(f.testCalls, [const Duration(seconds: 10)]);
        expect(
          find.text('Тестовое уведомление придёт через 10 секунд'),
          findsOneWidget,
        );
      },
      today: today,
      scheduler: f,
    );

    final g = FakeNotificationScheduler();
    appTest(
      'сохранённые настройки подхватываются при запуске',
      (tester, db) async {
        await openTab(tester, 'Настройки');

        expect(find.text('18:30'), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
        // Напоминание за день до платежа 20 октября — в 18:30.
        expect(g.lastPlan.first.fireAt, DateTime(2026, 10, 19, 18, 30));
      },
      today: today,
      seed: seedOne,
      scheduler: g,
      prefs: {
        'reminders_enabled': true,
        'reminders_minutes_of_day': 18 * 60 + 30,
      },
    );
  });
}
