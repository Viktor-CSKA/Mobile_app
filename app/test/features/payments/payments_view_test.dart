import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/payments/domain/payments_view.dart';
import 'package:flutter_test/flutter_test.dart';

const housing = Category(id: 1, name: 'ЖКХ', colorValue: 0xFF795548);
const subs = Category(id: 2, name: 'Подписки', colorValue: 0xFF8E24AA);
const loans = Category(id: 3, name: 'Кредиты', colorValue: 0xFFF44336);

PaymentWithCategory item(
  int id,
  String name,
  Category category, {
  int? amount = 10000,
  String note = '',
}) => PaymentWithCategory(
  Payment(
    id: id,
    name: name,
    categoryId: category.id,
    amountKopecks: amount,
    periodMonths: 1,
    nextDueAt: DateTime(2026, 10, id),
    anchorDay: id,
    remindDaysBefore: 1,
    endsAt: null,
    note: note,
    isActive: true,
  ),
  category,
);

void main() {
  final all = [
    item(1, 'Электричество', housing, amount: null),
    item(2, 'Яндекс Плюс', subs, amount: 39900),
    item(3, 'Квартплата', housing, amount: 580000),
    item(4, 'Ипотека', loans, amount: 3250000, note: 'Сбербанк'),
    item(5, 'Кинопоиск', subs, amount: 29900),
  ];

  group('поиск', () {
    test('пустой запрос оставляет всё, порядок прежний', () {
      expect(filterPayments(all, '').map((e) => e.payment.id), [1, 2, 3, 4, 5]);
      expect(filterPayments(all, '   '), same(all));
    });

    test('ищет по части названия без учёта регистра', () {
      expect(filterPayments(all, 'кино').map((e) => e.payment.name), [
        'Кинопоиск',
      ]);
      expect(filterPayments(all, 'ПЛЮС').map((e) => e.payment.id), [2]);
    });

    test('«е» находит «ё» и наоборот', () {
      final items = [item(1, 'Счётчик воды', housing)];
      expect(filterPayments(items, 'счетчик'), hasLength(1));
      expect(filterPayments(items, 'СЧЁТЧИК'), hasLength(1));
    });

    test('ищет и по заметке', () {
      expect(filterPayments(all, 'сбербанк').map((e) => e.payment.id), [4]);
    });

    test('ничего не нашлось — пустой список', () {
      expect(filterPayments(all, 'нет такого'), isEmpty);
    });

    test('лишние пробелы по краям не мешают', () {
      expect(filterPayments(all, '  ипотека  ').map((e) => e.payment.id), [4]);
    });
  });

  group('группировка по категориям', () {
    test('группы по номеру категории, внутри порядок по дате', () {
      final groups = groupByCategory(all);
      expect(groups.map((g) => g.category.name), [
        'ЖКХ',
        'Подписки',
        'Кредиты',
      ]);
      expect(groups[0].items.map((e) => e.payment.id), [1, 3]);
      expect(groups[1].items.map((e) => e.payment.id), [2, 5]);
      expect(groups[2].items.map((e) => e.payment.id), [4]);
    });

    test('сумма группы — только известные суммы, переменные считаются', () {
      final housingGroup = groupByCategory(all).first;
      expect(housingGroup.knownTotalKopecks, 580000);
      expect(housingGroup.variableCount, 1);

      final subsGroup = groupByCategory(all)[1];
      expect(subsGroup.knownTotalKopecks, 69800);
      expect(subsGroup.variableCount, 0);
    });

    test('пустой список — нет групп', () {
      expect(groupByCategory(const []), isEmpty);
    });

    test('поиск и группировка вместе: категории без совпадений пропадают', () {
      final groups = groupByCategory(filterPayments(all, 'и'));
      // «и» есть в названиях всех пяти, но проверим узкий запрос
      expect(groups, isNotEmpty);
      final narrow = groupByCategory(filterPayments(all, 'ипотека'));
      expect(narrow.single.category.name, 'Кредиты');
    });
  });
}
