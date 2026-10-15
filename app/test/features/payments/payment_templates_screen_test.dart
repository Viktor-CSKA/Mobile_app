import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Поле поиска внутри нижней панели (за ней в дереве остаются поля формы).
Finder searchField() => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(TextField),
);

Future<void> openNewPayment(WidgetTester tester) async {
  await openTab(tester, 'Платежи');
  await tester.tap(find.text('Добавить платёж'));
  await tester.pumpAndSettle();
}

Future<void> chip(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.widgetWithText(ActionChip, name));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ActionChip, name));
  await tester.pumpAndSettle();
}

String nameText(WidgetTester tester) =>
    tester.widget<TextFormField>(field('Название')).controller!.text;

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Сохранить'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Сохранить'));
  await tester.pumpAndSettle();
}

/// Чтение базы из виджет-теста — только через runAsync (иначе зависает).
Future<List<Payment>> allPayments(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() async {
      final items = await PaymentsRepository(db).watchActive().first;
      return items.map((e) => e.payment).toList();
    }))!;

void main() {
  appTest('на низком экране кнопка «Сохранить» видна без прокрутки', (
    tester,
    db,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    await openNewPayment(tester);

    final bottom = tester.getRect(find.text('Сохранить')).bottom;
    expect(bottom, lessThanOrEqualTo(700));
    // и она нажимается без прокрутки формы: срабатывает проверка полей
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название'), findsOneWidget);
  }, today: today);
  appTest('в новой форме есть быстрый выбор и «Все шаблоны»', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);

    expect(find.text('Быстрый выбор'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Электричество'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Яндекс Плюс'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Все шаблоны'), findsOneWidget);
  }, today: today);

  appTest(
    'шаблон коммунальной услуги: переменная сумма, категория ЖКХ, дата 10-го',
    (tester, db) async {
      await openNewPayment(tester);
      await chip(tester, 'Электричество');

      expect(nameText(tester), 'Электричество');
      expect(find.text('ЖКХ'), findsWidgets);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Сумма меняется'),
            )
            .value,
        isTrue,
      );
      expect(field('Сумма'), findsNothing);
      expect(
        find.text('10 ноября 2026'),
        findsOneWidget,
      ); // 10 октября уже прошло, сегодня 15-е
    },
    today: today,
  );

  appTest('шаблон подписки: категория «Подписки», поле суммы в фокусе', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);
    await chip(tester, 'Яндекс Плюс');

    expect(nameText(tester), 'Яндекс Плюс');
    expect(find.text('Подписки'), findsWidgets);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Сумма меняется'),
          )
          .value,
      isFalse,
    );
    final amount = tester.widget<EditableText>(
      find.descendant(of: field('Сумма'), matching: find.byType(EditableText)),
    );
    expect(amount.focusNode.hasFocus, isTrue);
  }, today: today);

  appTest('шаблон с вводом суммы сохраняется как обычный платёж', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);
    await chip(tester, 'Яндекс Плюс');
    await tester.enterText(field('Сумма'), '399');
    await tapSave(tester);

    final p = (await allPayments(tester, db)).single;
    expect(p.name, 'Яндекс Плюс');
    expect(p.amountKopecks, 39900);
    expect(p.periodMonths, 1);
    expect(find.text('Яндекс Плюс'), findsOneWidget);
  }, today: today);

  appTest('шаблон ЖКУ без суммы сохраняется с переменной суммой', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);
    await chip(tester, 'Квартплата (ЖКУ)');
    await tapSave(tester);

    final p = (await allPayments(tester, db)).single;
    expect(p.name, 'Квартплата (ЖКУ)');
    expect(p.amountKopecks, isNull);
    expect(p.nextDueAt, DateTime(2026, 11, 10));
    expect(p.anchorDay, 10);
  }, today: today);

  appTest('«Все шаблоны»: поиск и выбор ипотеки', (tester, db) async {
    await openNewPayment(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Все шаблоны'));
    await tester.pumpAndSettle();

    expect(find.text('Подписки'), findsWidgets); // заголовки групп
    await tester.enterText(searchField(), 'ипот');
    await tester.pumpAndSettle();
    // Под панелью остаётся форма с чипом «Ипотека», поэтому ищем плитку списка.
    expect(find.widgetWithText(ListTile, 'Ипотека'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Okko'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Ипотека'));
    await tester.pumpAndSettle();

    expect(nameText(tester), 'Ипотека');
    expect(find.text('Кредиты и ипотека'), findsWidgets);
  }, today: today);

  appTest('«Все шаблоны»: ничего не найдено', (tester, db) async {
    await openNewPayment(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Все шаблоны'));
    await tester.pumpAndSettle();
    await tester.enterText(searchField(), 'зззз');
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
  }, today: today);

  appTest('налог из списка: раз в год, 1 декабря, напоминание за неделю', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Все шаблоны'));
    await tester.pumpAndSettle();
    await tester.enterText(searchField(), 'имущество');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Налог на имущество'));
    await tester.pumpAndSettle();

    expect(find.text('1 декабря 2026'), findsOneWidget);
    expect(find.text('Раз в год'), findsOneWidget);
    expect(find.text('За неделю'), findsOneWidget);

    await tester.enterText(field('Сумма'), '4500');
    await tapSave(tester);

    final p = (await allPayments(tester, db)).single;
    expect(p.periodMonths, 12);
    expect(p.nextDueAt, DateTime(2026, 12, 1));
    expect(p.remindDaysBefore, 7);
    expect(p.amountKopecks, 450000);
  }, today: today);

  appTest('шаблон меняет ранее выбранное, а потом можно править вручную', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);
    await chip(tester, 'Яндекс Плюс');
    await chip(tester, 'Электричество'); // шаблон перезаписывает форму
    expect(nameText(tester), 'Электричество');
    expect(field('Сумма'), findsNothing);

    await tester.enterText(field('Название'), 'Электричество дача');
    await tapSave(tester);

    expect((await allPayments(tester, db)).single.name, 'Электричество дача');
  }, today: today);

  appTest('при редактировании платежа быстрого выбора нет', (tester, db) async {
    await openNewPayment(tester);
    await chip(tester, 'Яндекс Плюс');
    await tester.enterText(field('Сумма'), '399');
    await tapSave(tester);

    await tester.tap(find.text('Яндекс Плюс'));
    await tester.pumpAndSettle();

    expect(find.text('Платёж'), findsOneWidget); // заголовок режима правки
    expect(find.text('Быстрый выбор'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Все шаблоны'), findsNothing);
  }, today: today);
}
