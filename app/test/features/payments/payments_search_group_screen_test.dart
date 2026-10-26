import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/data/payments_view_providers.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

final today = DateTime(2026, 10, 15);

/// ЖКХ: Электричество (переменная) и Квартплата 5 800 ₽; Подписки: Яндекс Плюс.
/// В архиве: «Старый интернет».
Future<void> seedMixed(AppDatabase db) async {
  final repo = PaymentsRepository(db);
  final cats = await repo.watchCategories().first;
  int idOf(String name) => cats.firstWhere((c) => c.name == name).id;
  PaymentDraft d(String name, String cat, int day, int? amount) => PaymentDraft(
    name: name,
    categoryId: idOf(cat),
    amountKopecks: amount,
    nextDueAt: DateTime(2026, 10, day),
  );
  await repo.add(d('Яндекс Плюс', 'Подписки', 18, 39900));
  await repo.add(d('Электричество', 'ЖКХ', 12, null));
  await repo.add(d('Квартплата', 'ЖКХ', 20, 580000));
  final old = await repo.add(
    d('Старый интернет', 'Связь и интернет', 5, 50000),
  );
  await repo.archive(old);
}

Finder tile(String name) => find.widgetWithText(ListTile, name);

Future<void> openPayments(WidgetTester tester) => openTab(tester, 'Платежи');

Future<void> search(WidgetTester tester, String text) async {
  await tester.tap(find.byTooltip('Поиск'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  appTest(
    'по умолчанию — один список по дате, без заголовков категорий',
    (tester, db) async {
      await openPayments(tester);

      expect(tile('Электричество'), findsOneWidget);
      final first = tester.getTopLeft(tile('Электричество')).dy;
      final second = tester.getTopLeft(tile('Яндекс Плюс')).dy;
      final third = tester.getTopLeft(tile('Квартплата')).dy;
      expect(first, lessThan(second));
      expect(second, lessThan(third));
    },
    today: today,
    seed: seedMixed,
  );

  appTest(
    'группировка по категориям: заголовки с числом и суммой, выбор запоминается',
    (tester, db) async {
      await openPayments(tester);

      await tester.tap(find.byTooltip('Вид списка'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('По категориям'));
      await tester.pumpAndSettle();

      // ЖКХ (2 платежа, известная сумма 5 800 ₽) идёт раньше «Подписок».
      expect(find.textContaining('2 · 5'), findsOneWidget);
      final housing = tester.getTopLeft(find.text('ЖКХ').first).dy;
      final subs = tester.getTopLeft(find.text('Подписки').first).dy;
      expect(housing, lessThan(subs));
      // Внутри ЖКХ платежи по дате: Электричество (12) раньше Квартплаты (20).
      expect(
        tester.getTopLeft(tile('Электричество')).dy,
        lessThan(tester.getTopLeft(tile('Квартплата')).dy),
      );
      // Яндекс Плюс (18 октября) теперь ниже Квартплаты (20): он в другой группе.
      expect(
        tester.getTopLeft(tile('Квартплата')).dy,
        lessThan(tester.getTopLeft(tile('Яндекс Плюс')).dy),
      );
    },
    today: today,
    seed: seedMixed,
  );

  appTest(
    'сохранённая группировка применяется при запуске',
    (tester, db) async {
      await openPayments(tester);
      expect(find.textContaining('2 · 5'), findsOneWidget);
    },
    today: today,
    seed: seedMixed,
    prefs: {PaymentsGroupingNotifier.key: true},
  );

  appTest(
    'поиск оставляет только подходящие платежи',
    (tester, db) async {
      await openPayments(tester);
      await search(tester, 'кварт');

      expect(tile('Квартплата'), findsOneWidget);
      expect(tile('Электричество'), findsNothing);
      expect(tile('Яндекс Плюс'), findsNothing);
    },
    today: today,
    seed: seedMixed,
  );

  appTest(
    'поиск находит платёж в архиве и раскрывает архив',
    (tester, db) async {
      await openPayments(tester);
      expect(tile('Старый интернет'), findsNothing); // архив свёрнут

      await search(tester, 'интернет');

      expect(tile('Старый интернет'), findsOneWidget);
      expect(find.textContaining('Архив · 1'), findsOneWidget);
      expect(tile('Квартплата'), findsNothing);
    },
    today: today,
    seed: seedMixed,
  );

  appTest(
    'ничего не найдено: сообщение; закрытие поиска возвращает список',
    (tester, db) async {
      await openPayments(tester);
      await search(tester, 'нет такого платежа');

      expect(find.text('Ничего не найдено.'), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть поиск'));
      await tester.pumpAndSettle();

      expect(find.text('Ничего не найдено.'), findsNothing);
      expect(tile('Квартплата'), findsOneWidget);
      expect(tile('Электричество'), findsOneWidget);
    },
    today: today,
    seed: seedMixed,
  );

  appTest(
    'кнопка «Очистить» стирает запрос',
    (tester, db) async {
      await openPayments(tester);
      await search(tester, 'кварт');
      expect(tile('Электричество'), findsNothing);

      await tester.tap(find.byTooltip('Очистить'));
      await tester.pumpAndSettle();

      expect(tile('Электричество'), findsOneWidget);
    },
    today: today,
    seed: seedMixed,
  );

  appTest(
    'платёж из результатов поиска открывается',
    (tester, db) async {
      await openPayments(tester);
      await search(tester, 'электр');

      await tester.tap(tile('Электричество'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Платёж'), findsOneWidget);
    },
    today: today,
    seed: seedMixed,
  );
}
