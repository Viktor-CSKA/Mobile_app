import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Нажимает «Сохранить», предварительно прокрутив форму до кнопки.
Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Сохранить'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Сохранить'));
  await tester.pumpAndSettle();
}

Future<void> addPayment(
  WidgetTester tester, {
  required String name,
  String? amount,
}) async {
  await tester.tap(find.text('Добавить платёж'));
  await tester.pumpAndSettle();
  await tester.enterText(field('Название'), name);
  if (amount != null) {
    await tester.enterText(field('Сумма'), amount);
  }
}

void main() {
  appTest('пустой список показывает подсказку', (tester, db) async {
    await openTab(tester, 'Платежи');

    expect(find.textContaining('Платежей пока нет'), findsOneWidget);
    expect(find.text('Добавить платёж'), findsOneWidget);
  });

  appTest('форма не сохраняет платёж без названия и суммы', (tester, db) async {
    await openTab(tester, 'Платежи');
    await tester.tap(find.text('Добавить платёж'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(find.text('Введите название'), findsOneWidget);
    expect(find.text('Введите сумму'), findsOneWidget);
    expect(find.text('Новый платёж'), findsOneWidget);
  });

  appTest('добавление платежа показывает его в списке', (tester, db) async {
    await openTab(tester, 'Платежи');
    await addPayment(tester, name: 'Интернет', amount: '690');
    await tapSave(tester);

    expect(find.text('Новый платёж'), findsNothing);
    expect(find.text('Интернет'), findsOneWidget);
    expect(find.textContaining('690'), findsOneWidget);
    expect(find.textContaining('Каждый месяц'), findsOneWidget);
  });

  appTest('платёж с переменной суммой подписан «сумма меняется»', (
    tester,
    db,
  ) async {
    await openTab(tester, 'Платежи');
    await addPayment(tester, name: 'Электричество');
    await tester.tap(find.text('Сумма меняется'));
    await tester.pumpAndSettle();
    expect(field('Сумма'), findsNothing);

    await tapSave(tester);

    expect(find.text('Электричество'), findsOneWidget);
    expect(find.text('сумма меняется'), findsOneWidget);
  });

  appTest('редактирование меняет название, удаление убирает платёж', (
    tester,
    db,
  ) async {
    await openTab(tester, 'Платежи');
    await addPayment(tester, name: 'Кино', amount: '299');
    await tapSave(tester);

    await tester.tap(find.text('Кино'));
    await tester.pumpAndSettle();
    expect(find.text('Платёж'), findsOneWidget);
    await tester.enterText(field('Название'), 'Кинопоиск');
    await tapSave(tester);
    expect(find.text('Кинопоиск'), findsOneWidget);
    expect(find.text('Кино'), findsNothing);

    await tester.tap(find.text('Кинопоиск'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Кинопоиск'), findsNothing);
    expect(find.textContaining('Платежей пока нет'), findsOneWidget);
  });
}
