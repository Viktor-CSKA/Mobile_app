import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> openNewForm(WidgetTester tester) async {
  await openTab(tester, 'Платежи');
  await tester.tap(find.text('Добавить платёж'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Сохранить'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Сохранить'));
  await tester.pumpAndSettle();
}

Future<void> addNamed(WidgetTester tester, String name, String amount) async {
  await openNewForm(tester);
  await tester.enterText(field('Название'), name);
  await tester.enterText(field('Сумма'), amount);
}

void main() {
  appTest('форма нового платежа показывает быстрые шаблоны и поля', (
    tester,
    db,
  ) async {
    await openNewForm(tester);

    expect(find.text('Новый платёж'), findsOneWidget);
    expect(find.text('Быстрый выбор'), findsOneWidget);
    expect(find.text('Все шаблоны'), findsOneWidget);
    expect(field('Название'), findsOneWidget);
    expect(find.text('Категория'), findsOneWidget);
    expect(find.text('Сумма меняется'), findsOneWidget);
    expect(field('Сумма'), findsOneWidget);
    expect(find.text('Как часто'), findsOneWidget);
    expect(find.text('Ближайший платёж'), findsOneWidget);
    expect(find.text('Напомнить'), findsOneWidget);
    expect(find.text('Заметка'), findsOneWidget);
    // У нового платежа нет действий архива и удаления.
    expect(find.byTooltip('В архив'), findsNothing);
    expect(find.byTooltip('Удалить'), findsNothing);
  });

  appTest('заметка сохраняется вместе с платежом', (tester, db) async {
    await addNamed(tester, 'Интернет', '690');
    await tester.enterText(field('Заметка'), 'Проводной, роутер');
    await tapSave(tester);

    // Открываем платёж и проверяем заметку в форме.
    await tester.tap(find.text('Интернет'));
    await tester.pumpAndSettle();
    expect(find.text('Проводной, роутер'), findsOneWidget);
  });

  appTest('дата окончания кредита сохраняется', (tester, db) async {
    await addNamed(tester, 'Кредит', '15000');
    await tester.tap(find.text('Есть дата окончания'));
    await tester.pumpAndSettle();

    // После включения появился выбор последнего платежа.
    expect(find.text('Последний платёж'), findsOneWidget);
    await tapSave(tester);

    await tester.tap(find.text('Кредит'));
    await tester.pumpAndSettle();
    expect(find.text('Есть дата окончания'), findsOneWidget);
    expect(find.text('Последний платёж'), findsOneWidget);
  });

  appTest('выключение даты окончания убирает выбор последнего платежа', (
    tester,
    db,
  ) async {
    await addNamed(tester, 'Рассрочка', '5000');
    await tester.tap(find.text('Есть дата окончания'));
    await tester.pumpAndSettle();
    expect(find.text('Последний платёж'), findsOneWidget);

    await tester.tap(find.text('Есть дата окончания'));
    await tester.pumpAndSettle();
    expect(find.text('Последний платёж'), findsNothing);
  });

  appTest('переменная сумма убирает поле суммы и наоборот', (tester, db) async {
    await openNewForm(tester);
    await tester.enterText(field('Название'), 'Свет');
    expect(field('Сумма'), findsOneWidget);

    await tester.tap(find.text('Сумма меняется'));
    await tester.pumpAndSettle();
    expect(field('Сумма'), findsNothing);

    await tester.tap(find.text('Сумма меняется'));
    await tester.pumpAndSettle();
    expect(field('Сумма'), findsOneWidget);
  });

  appTest('сохранение с пустой заметкой оставляет её пустой', (
    tester,
    db,
  ) async {
    await addNamed(tester, 'Яндекс Плюс', '299');
    await tapSave(tester);

    await tester.tap(find.text('Яндекс Плюс'));
    await tester.pumpAndSettle();
    final note = tester
        .widget<TextFormField>(field('Заметка'))
        .controller!
        .text;
    expect(note, isEmpty);
  });
}
