import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/upcoming/domain/upcoming_summary.dart';
import 'package:ezhemesyachno/features/upcoming/presentation/upcoming_labels.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = Category(id: 1, name: 'Подписки', colorValue: 0xFF8E24AA);

PaymentWithCategory pay(
  String name,
  DateTime due, {
  int? amount = 10000,
  int period = 1,
  DateTime? ends,
  bool active = true,
}) => PaymentWithCategory(
  Payment(
    id: name.hashCode,
    name: name,
    categoryId: 1,
    amountKopecks: amount,
    periodMonths: period,
    nextDueAt: due,
    anchorDay: due.day,
    remindDaysBefore: 1,
    endsAt: ends,
    note: '',
    isActive: active,
  ),
  _category,
);

void main() {
  final today = DateTime(2026, 10, 15, 14, 30);

  group('разделение и порядок', () {
    test('просроченные отдельно, самые старые сверху', () {
      final s = UpcomingSummary.build([
        pay('Б', DateTime(2026, 10, 10)),
        pay('А', DateTime(2026, 10, 1)),
        pay('В', DateTime(2026, 10, 20)),
      ], today);
      expect(s.overdue.map((e) => e.payment.name), ['А', 'Б']);
      expect(s.upcoming.map((e) => e.payment.name), ['В']);
    });

    test('платёж сегодня не считается просроченным', () {
      final s = UpcomingSummary.build([
        pay('Сегодня', DateTime(2026, 10, 15)),
      ], today);
      expect(s.overdue, isEmpty);
      expect(s.upcoming.length, 1);
    });

    test('ближайшие по возрастанию даты, при равенстве по названию', () {
      final s = UpcomingSummary.build([
        pay('Я', DateTime(2026, 10, 20)),
        pay('Б', DateTime(2026, 10, 18)),
        pay('А', DateTime(2026, 10, 20)),
      ], today);
      expect(s.upcoming.map((e) => e.payment.name), ['Б', 'А', 'Я']);
    });

    test('неактивные платежи не показываются', () {
      final s = UpcomingSummary.build([
        pay('Закрыт', DateTime(2026, 10, 20), active: false),
      ], today);
      expect(s.isEmpty, isTrue);
    });

    test('пустой список', () {
      final s = UpcomingSummary.build(const [], today);
      expect(s.isEmpty, isTrue);
      expect(s.needThisMonth.totalKopecks, 0);
      expect(s.needThisMonth.paymentsCount, 0);
    });
  });

  group('сумма «нужно в этом месяце»', () {
    test('просрочка плюс остаток месяца, без следующего месяца', () {
      final s = UpcomingSummary.build([
        pay('Просрочен', DateTime(2026, 10, 10), amount: 50000),
        pay('Сегодня', DateTime(2026, 10, 15), amount: 20000),
        pay('Конец месяца', DateTime(2026, 10, 31), amount: 30000),
        pay('Ноябрь', DateTime(2026, 11, 1), amount: 99900),
      ], today);
      expect(s.needThisMonth.totalKopecks, 100000);
      expect(s.needThisMonth.paymentsCount, 3);
    });

    test('переменная сумма считается отдельно', () {
      final s = UpcomingSummary.build([
        pay('Фикс', DateTime(2026, 10, 20), amount: 10000),
        pay('ЖКХ', DateTime(2026, 10, 25), amount: null),
      ], today);
      expect(s.needThisMonth.totalKopecks, 10000);
      expect(s.needThisMonth.variableCount, 1);
      expect(s.needThisMonth.paymentsCount, 2);
    });

    test('просрочка на несколько месяцев считается один раз', () {
      final s = UpcomingSummary.build([
        pay('Давний', DateTime(2026, 7, 15), amount: 10000),
      ], today);
      // Один долг + платёж 15 октября (сегодня), июль–сентябрь не накапливаются.
      expect(s.needThisMonth.paymentsCount, 2);
      expect(s.needThisMonth.totalKopecks, 20000);
      expect(s.overdueForecast.paymentsCount, 1);
    });

    test('уже оплаченный в этом месяце платёж не входит', () {
      // nextDueAt уже в ноябре — значит, октябрьский оплачен.
      final s = UpcomingSummary.build([
        pay('Оплачен', DateTime(2026, 11, 15), amount: 10000),
      ], today);
      expect(s.needThisMonth.paymentsCount, 0);
    });

    test('закончившийся кредит не добавляет лишнего', () {
      final s = UpcomingSummary.build([
        pay(
          'Кредит',
          DateTime(2026, 10, 20),
          amount: 500000,
          ends: DateTime(2026, 10, 20),
        ),
      ], today);
      expect(s.needThisMonth.paymentsCount, 1);
    });
  });

  group('просроченное', () {
    test('сумма и количество только просроченных', () {
      final s = UpcomingSummary.build([
        pay('П1', DateTime(2026, 10, 1), amount: 10000),
        pay('П2', DateTime(2026, 10, 14), amount: null),
        pay('Будущий', DateTime(2026, 10, 20), amount: 99900),
      ], today);
      expect(s.overdueForecast.paymentsCount, 2);
      expect(s.overdueForecast.totalKopecks, 10000);
      expect(s.overdueForecast.variableCount, 1);
    });
  });

  group('dueLabel', () {
    test('просрочено', () => expect(dueLabel(-3), 'просрочено на 3 дн.'));
    test('сегодня', () => expect(dueLabel(0), 'сегодня'));
    test('завтра', () => expect(dueLabel(1), 'завтра'));
    test('через несколько дней', () => expect(dueLabel(5), 'через 5 дн.'));
  });
}
