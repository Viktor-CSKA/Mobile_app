import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/core/format/date_format_ru.dart';
import 'package:ezhemesyachno/features/calendar/domain/month_calendar.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

const _utilities = Category(id: 1, name: 'ЖКХ', colorValue: 0xFF795548);

PaymentWithCategory scheduled(
  String name,
  DateTime due, {
  int? amount = 10000,
  int period = 1,
  int? anchor,
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
    anchorDay: anchor ?? due.day,
    remindDaysBefore: 1,
    endsAt: ends,
    note: '',
    isActive: active,
  ),
  _utilities,
);

PaidEntry paidOn(String name, DateTime paidAt, int amount) {
  final payment = scheduled(name, paidAt).payment;
  return PaidEntry(
    PaymentRecord(
      id: name.hashCode,
      paymentId: payment.id,
      amountKopecks: amount,
      paidAt: paidAt,
    ),
    payment,
    _utilities,
  );
}

MonthCalendar build({
  DateTime? month,
  DateTime? today,
  List<PaymentWithCategory> items = const [],
  List<PaidEntry> paid = const [],
}) => MonthCalendar.build(
  month: month ?? DateTime(2026, 10),
  today: today ?? DateTime(2026, 10, 15),
  scheduled: items,
  paid: paid,
);

void main() {
  group('сетка месяца', () {
    test('октябрь 2026 начинается с четверга', () {
      final c = build();
      expect(c.leadingBlanks, 3);
      expect(c.daysCount, 31);
    });

    test('месяц, начинающийся с понедельника, без пустых клеток', () {
      expect(build(month: DateTime(2026, 6)).leadingBlanks, 0);
    });

    test('месяц, начинающийся с воскресенья', () {
      expect(build(month: DateTime(2026, 11)).leadingBlanks, 6);
    });

    test('февраль високосного года', () {
      final c = build(month: DateTime(2028, 2));
      expect(c.daysCount, 29);
      expect(c.leadingBlanks, 1);
    });

    test('месяц нормализуется к первому числу', () {
      expect(build(month: DateTime(2026, 10, 17)).month, DateTime(2026, 10));
    });
  });

  group('запланированные платежи', () {
    test('попадают на свои дни', () {
      final c = build(
        items: [
          scheduled('Интернет', DateTime(2026, 10, 20)),
          scheduled('Кредит', DateTime(2026, 10, 25)),
        ],
      );
      expect(c.entriesOn(DateTime(2026, 10, 20)).single.name, 'Интернет');
      expect(c.entriesOn(DateTime(2026, 10, 25)).single.name, 'Кредит');
      expect(c.hasEntries(DateTime(2026, 10, 21)), isFalse);
    });

    test('время суток в дате игнорируется', () {
      final c = build(items: [scheduled('А', DateTime(2026, 10, 20))]);
      expect(c.hasEntries(DateTime(2026, 10, 20, 23, 59)), isTrue);
    });

    test('ежемесячный платёж виден и в следующих месяцах', () {
      final item = scheduled('Интернет', DateTime(2026, 10, 20));
      final nov = build(month: DateTime(2026, 11), items: [item]);
      expect(nov.entriesOn(DateTime(2026, 11, 20)), hasLength(1));
    });

    test('в месяцах до ближайшей даты платежа нет', () {
      final item = scheduled('Интернет', DateTime(2026, 10, 20));
      final sep = build(month: DateTime(2026, 9), items: [item]);
      expect(sep.totals.plannedKopecks, 0);
    });

    test('31-е в феврале переносится на последний день', () {
      final item = scheduled('Аренда', DateTime(2026, 1, 31));
      final feb = build(month: DateTime(2026, 2), items: [item]);
      expect(feb.entriesOn(DateTime(2026, 2, 28)).single.name, 'Аренда');
    });

    test('годовой платёж показывается только в нужный месяц', () {
      final item = scheduled('Страховка', DateTime(2026, 12, 5), period: 12);
      expect(
        build(month: DateTime(2026, 11), items: [item]).totals.plannedKopecks,
        0,
      );
      expect(
        build(month: DateTime(2026, 12), items: [item]).totals.plannedKopecks,
        10000,
      );
      expect(
        build(month: DateTime(2027, 1), items: [item]).totals.plannedKopecks,
        0,
      );
      expect(
        build(month: DateTime(2027, 12), items: [item]).totals.plannedKopecks,
        10000,
      );
    });

    test('окончание кредита обрезает календарь', () {
      final item = scheduled(
        'Кредит',
        DateTime(2026, 10, 10),
        ends: DateTime(2026, 11, 10),
      );
      expect(
        build(
          month: DateTime(2026, 11),
          items: [item],
        ).hasEntries(DateTime(2026, 11, 10)),
        isTrue,
      );
      expect(
        build(month: DateTime(2026, 12), items: [item]).totals.plannedKopecks,
        0,
      );
    });

    test('неактивные платежи не показываются', () {
      final c = build(
        items: [scheduled('Закрыт', DateTime(2026, 10, 20), active: false)],
      );
      expect(c.totals.plannedKopecks, 0);
    });

    test('прошедшие и неоплаченные помечены просроченными', () {
      final c = build(
        items: [
          scheduled('Старый', DateTime(2026, 10, 10)),
          scheduled('Сегодня', DateTime(2026, 10, 15)),
          scheduled('Будущий', DateTime(2026, 10, 20)),
        ],
      );
      expect(c.entriesOn(DateTime(2026, 10, 10)).single.overdue, isTrue);
      expect(c.entriesOn(DateTime(2026, 10, 15)).single.overdue, isFalse);
      expect(c.entriesOn(DateTime(2026, 10, 20)).single.overdue, isFalse);
    });
  });

  group('оплаченные', () {
    test('показываются на день оплаты', () {
      final c = build(
        paid: [paidOn('Вода', DateTime(2026, 10, 12, 18, 30), 40000)],
      );
      final e = c.entriesOn(DateTime(2026, 10, 12)).single;
      expect(e.paid, isTrue);
      expect(e.amountKopecks, 40000);
      expect(e.overdue, isFalse);
    });

    test('оплаты других месяцев игнорируются', () {
      final c = build(
        paid: [
          paidOn('Прошлый', DateTime(2026, 9, 30), 10000),
          paidOn('Следующий', DateTime(2026, 11, 1), 10000),
        ],
      );
      expect(c.totals.paidKopecks, 0);
    });

    test(
      'в один день: запланированные раньше оплаченных, дальше по названию',
      () {
        final c = build(
          items: [
            scheduled('Я', DateTime(2026, 10, 20)),
            scheduled('Б', DateTime(2026, 10, 20)),
          ],
          paid: [paidOn('А', DateTime(2026, 10, 20), 5000)],
        );
        final names = c.entriesOn(DateTime(2026, 10, 20)).map((e) => e.name);
        expect(names, ['Б', 'Я', 'А']);
      },
    );
  });

  group('итоги месяца', () {
    test('запланировано, оплачено и переменные суммы', () {
      final c = build(
        items: [
          scheduled('Интернет', DateTime(2026, 10, 20), amount: 69000),
          scheduled('Кредит', DateTime(2026, 10, 25), amount: 1200000),
          scheduled('Свет', DateTime(2026, 10, 10), amount: null),
        ],
        paid: [paidOn('Вода', DateTime(2026, 10, 12), 40000)],
      );
      expect(c.totals.plannedKopecks, 1269000);
      expect(c.totals.variableCount, 1);
      expect(c.totals.paidKopecks, 40000);
    });

    test('пустой месяц', () {
      final t = build().totals;
      expect(t.plannedKopecks, 0);
      expect(t.paidKopecks, 0);
      expect(t.variableCount, 0);
    });
  });

  group('shiftMonth и daysBetween', () {
    test('декабрь + 1 = январь следующего года', () {
      expect(shiftMonth(DateTime(2026, 12), 1), DateTime(2027, 1));
    });
    test('январь − 1 = декабрь прошлого года', () {
      expect(shiftMonth(DateTime(2026, 1), -1), DateTime(2025, 12));
    });
    test('сдвиг на несколько месяцев', () {
      expect(shiftMonth(DateTime(2026, 10), 14), DateTime(2027, 12));
    });
    test('дни между датами', () {
      expect(daysBetween(DateTime(2026, 10, 15), DateTime(2026, 10, 20)), 5);
      expect(daysBetween(DateTime(2026, 10, 15), DateTime(2026, 10, 10)), -5);
      expect(
        daysBetween(DateTime(2026, 10, 15, 23), DateTime(2026, 10, 16, 1)),
        1,
      );
    });
    test('через границу года и високосный день', () {
      expect(daysBetween(DateTime(2027, 12, 31), DateTime(2028, 1, 1)), 1);
      expect(daysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 2);
    });
  });

  test('заголовок месяца', () {
    expect(formatMonthYear(DateTime(2026, 10, 5)), 'Октябрь 2026');
    expect(formatMonthYear(DateTime(2027, 3)), 'Март 2027');
  });
}
