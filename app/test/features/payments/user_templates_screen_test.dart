import 'package:ezhemesyachno/core/format/money.dart';
import 'package:ezhemesyachno/features/payments/data/user_templates_providers.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_templates.dart';
import 'package:ezhemesyachno/features/payments/domain/user_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> openNewPayment(WidgetTester tester) async {
  await openTab(tester, 'Платежи');
  await tester.tap(find.text('Добавить платёж'));
  await tester.pumpAndSettle();
}

final gym = PaymentTemplate(
  'Спортзал',
  'Подписки',
  periodMonths: 3,
  amountKopecks: 250000,
  remindDaysBefore: 7,
  dayOfMonth: 5,
);

Map<String, Object> withGym() => {
  UserTemplatesNotifier.key: encodeUserTemplates([gym]),
};

void main() {
  appTest('форму можно запомнить как шаблон и выбрать в новом платеже', (
    tester,
    db,
  ) async {
    await openNewPayment(tester);
    await tester.enterText(field('Название'), 'Спортзал');
    await tester.enterText(field('Сумма'), '2500');

    await tester.tap(find.byTooltip('Запомнить как шаблон'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Шаблон «Спортзал» сохранён'), findsOneWidget);

    // Новая форма: свой шаблон в быстром выборе, выбор заполняет поля.
    // Снэкбар живёт несколько секунд и закрывает нижнюю кнопку списка.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await tester.tap(find.text('Добавить платёж'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'Спортзал'));
    await tester.pumpAndSettle();
    expect(find.text('Спортзал'), findsWidgets);
    expect(
      tester.widget<TextFormField>(field('Сумма')).controller!.text,
      '2500',
    );
  }, today: today);

  appTest('пустая форма в шаблон не сохраняется', (tester, db) async {
    await openNewPayment(tester);

    await tester.tap(find.byTooltip('Запомнить как шаблон'));
    await tester.pumpAndSettle();

    expect(find.text('Введите название'), findsOneWidget);
    expect(find.textContaining('сохранён'), findsNothing);
  }, today: today);

  appTest('шаблон сохраняется на устройстве', (tester, db) async {
    await openNewPayment(tester);
    await tester.enterText(field('Название'), 'Школа');
    await tester.enterText(field('Сумма'), '4000');
    await tester.tap(find.byTooltip('Запомнить как шаблон'));
    await tester.pumpAndSettle();

    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    final saved = decodeUserTemplates(
      prefs.getString(UserTemplatesNotifier.key),
    );
    expect(saved.single.name, 'Школа');
    expect(saved.single.amountKopecks, 400000);
  }, today: today);

  appTest(
    'сохранённые шаблоны подхватываются при запуске',
    (tester, db) async {
      await openNewPayment(tester);
      expect(find.widgetWithText(ActionChip, 'Спортзал'), findsOneWidget);
    },
    today: today,
    prefs: withGym(),
  );

  appTest(
    'в списке всех шаблонов сверху «Мои шаблоны»; выбор заполняет форму',
    (tester, db) async {
      await openNewPayment(tester);
      await tester.tap(find.text('Все шаблоны'));
      await tester.pumpAndSettle();

      expect(find.text('Мои шаблоны'), findsOneWidget);
      // В подписи шаблона видна его сумма.
      expect(find.textContaining(formatKopecks(250000)), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Спортзал'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(field('Сумма')).controller!.text,
        '2500',
      );
      expect(find.text('Раз в квартал'), findsWidgets);
    },
    today: today,
    prefs: withGym(),
  );

  appTest(
    'шаблон можно удалить из списка',
    (tester, db) async {
      await openNewPayment(tester);
      await tester.tap(find.text('Все шаблоны'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Удалить шаблон «Спортзал»'));
      await tester.pumpAndSettle();

      expect(find.text('Мои шаблоны'), findsNothing);
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      expect(
        decodeUserTemplates(prefs.getString(UserTemplatesNotifier.key)),
        isEmpty,
      );
    },
    today: today,
    prefs: withGym(),
  );

  appTest(
    'поиск в списке шаблонов находит и свои',
    (tester, db) async {
      await openNewPayment(tester);
      await tester.tap(find.text('Все шаблоны'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'кружок');
      await tester.pumpAndSettle();

      // Названия «Кружок рисования» нет в готовых шаблонах: найден свой.
      expect(find.widgetWithText(ListTile, 'Кружок рисования'), findsOneWidget);
      expect(find.text('Мои шаблоны'), findsOneWidget);
      expect(find.text('Вода'), findsNothing);
    },
    today: today,
    prefs: {
      UserTemplatesNotifier.key: encodeUserTemplates([
        PaymentTemplate('Кружок рисования', 'Прочее', amountKopecks: 150000),
      ]),
    },
  );
}
