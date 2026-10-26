import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/stats/domain/year_stats.dart';
import 'package:flutter_test/flutter_test.dart';

const housing = Category(id: 1, name: 'ЖКХ', colorValue: 0xFF795548);
const subs = Category(id: 4, name: 'Подписки', colorValue: 0xFF8E24AA);

int _nextId = 0;

PaidEntry paid(Category category, DateTime at, int kopecks) {
  final id = ++_nextId;
  return PaidEntry(
    PaymentRecord(id: id, paymentId: id, amountKopecks: kopecks, paidAt: at),
    Payment(
      id: id,
      name: 'Платёж $id',
      categoryId: category.id,
      amountKopecks: kopecks,
      periodMonths: 1,
      nextDueAt: at,
      anchorDay: at.day,
      remindDaysBefore: 1,
      endsAt: null,
      note: '',
      isActive: true,
    ),
    category,
  );
}

void main() {
  test('пустая история: нулевые итоги, 12 месяцев', () {
    final s = YearStats.build(2026, const []);
    expect(s.isEmpty, isTrue);
    expect(s.totalKopecks, 0);
    expect(s.paymentsCount, 0);
    expect(s.byMonthKopecks, List.filled(12, 0));
    expect(s.byCategory, isEmpty);
    expect(s.maxMonthKopecks, 0);
  });

  test('итог, число оплат и суммы по месяцам', () {
    final s = YearStats.build(2026, [
      paid(housing, DateTime(2026, 1, 10), 100000),
      paid(housing, DateTime(2026, 1, 25), 50000),
      paid(subs, DateTime(2026, 3, 5), 39900),
      paid(subs, DateTime(2026, 12, 31, 23, 59), 29900),
    ]);
    expect(s.isEmpty, isFalse);
    expect(s.paymentsCount, 4);
    expect(s.totalKopecks, 219800);
    expect(s.byMonthKopecks[0], 150000);
    expect(s.byMonthKopecks[2], 39900);
    expect(s.byMonthKopecks[11], 29900);
    expect(s.byMonthKopecks[5], 0);
    expect(s.maxMonthKopecks, 150000);
  });

  test('оплаты других лет не учитываются', () {
    final s = YearStats.build(2026, [
      paid(housing, DateTime(2025, 12, 31, 23, 59), 100000),
      paid(housing, DateTime(2027, 1, 1), 100000),
      paid(housing, DateTime(2026, 6, 1), 70000),
    ]);
    expect(s.paymentsCount, 1);
    expect(s.totalKopecks, 70000);
    expect(s.byMonthKopecks[5], 70000);
  });

  test('категории: суммы вместе, от большей к меньшей', () {
    final s = YearStats.build(2026, [
      paid(subs, DateTime(2026, 2, 1), 39900),
      paid(housing, DateTime(2026, 2, 2), 100000),
      paid(subs, DateTime(2026, 3, 1), 39900),
      paid(housing, DateTime(2026, 3, 2), 20000),
    ]);
    expect(s.byCategory.map((c) => c.category.name), ['ЖКХ', 'Подписки']);
    expect(s.byCategory[0].kopecks, 120000);
    expect(s.byCategory[1].kopecks, 79800);
  });

  test('оплата на сумму 0 считается оплатой, но в итог ничего не даёт', () {
    final s = YearStats.build(2026, [paid(housing, DateTime(2026, 4, 1), 0)]);
    expect(s.paymentsCount, 1);
    expect(s.totalKopecks, 0);
    expect(s.isEmpty, isFalse);
  });

  test('списки нельзя изменить снаружи', () {
    final s = YearStats.build(2026, [paid(housing, DateTime(2026, 4, 1), 1)]);
    expect(() => s.byMonthKopecks[0] = 5, throwsUnsupportedError);
    expect(() => s.byCategory.clear(), throwsUnsupportedError);
  });
}
