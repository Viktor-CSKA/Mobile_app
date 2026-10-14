import 'package:ezhemesyachno/features/payments/domain/payment_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentSchedule schedule(
  DateTime next, {
  int? anchor,
  int period = 1,
  DateTime? ends,
}) => PaymentSchedule(
  nextDueAt: next,
  anchorDay: anchor ?? next.day,
  periodMonths: period,
  endsAt: ends,
);

void main() {
  group('nextDueDate', () {
    test('обычный месяц сохраняет день', () {
      final d = nextDueDate(
        current: DateTime(2026, 3, 15),
        anchorDay: 15,
        periodMonths: 1,
      );
      expect(d, DateTime(2026, 4, 15));
    });

    test('31-е: февраль даёт 28-е, март возвращает 31-е', () {
      final feb = nextDueDate(
        current: DateTime(2026, 1, 31),
        anchorDay: 31,
        periodMonths: 1,
      );
      expect(feb, DateTime(2026, 2, 28));
      final mar = nextDueDate(current: feb, anchorDay: 31, periodMonths: 1);
      expect(mar, DateTime(2026, 3, 31));
    });

    test('високосный год: февраль 29', () {
      final d = nextDueDate(
        current: DateTime(2028, 1, 31),
        anchorDay: 31,
        periodMonths: 1,
      );
      expect(d, DateTime(2028, 2, 29));
    });

    test('30-е: апрель остаётся 30-м', () {
      final d = nextDueDate(
        current: DateTime(2026, 3, 30),
        anchorDay: 30,
        periodMonths: 1,
      );
      expect(d, DateTime(2026, 4, 30));
    });

    test('переход через год', () {
      final d = nextDueDate(
        current: DateTime(2026, 12, 10),
        anchorDay: 10,
        periodMonths: 1,
      );
      expect(d, DateTime(2027, 1, 10));
    });

    test('раз в квартал', () {
      final d = nextDueDate(
        current: DateTime(2026, 11, 5),
        anchorDay: 5,
        periodMonths: 3,
      );
      expect(d, DateTime(2027, 2, 5));
    });

    test('раз в год, 29 февраля в невисокосный год', () {
      final d = nextDueDate(
        current: DateTime(2028, 2, 29),
        anchorDay: 29,
        periodMonths: 12,
      );
      expect(d, DateTime(2029, 2, 28));
    });

    test('время суток игнорируется только в расписании, не в функции', () {
      final d = nextDueDate(
        current: DateTime(2026, 5, 20, 23, 59),
        anchorDay: 20,
        periodMonths: 1,
      );
      expect(d, DateTime(2026, 6, 20));
    });
  });

  group('PaymentSchedule.followingDue', () {
    test('бессрочный платёж всегда имеет следующую дату', () {
      expect(
        schedule(DateTime(2026, 1, 31)).followingDue(),
        DateTime(2026, 2, 28),
      );
    });

    test('последний платёж кредита: следующей даты нет', () {
      final s = schedule(DateTime(2026, 6, 10), ends: DateTime(2026, 6, 10));
      expect(s.followingDue(), isNull);
    });

    test('день окончания включается', () {
      final s = schedule(DateTime(2026, 5, 10), ends: DateTime(2026, 6, 10));
      expect(s.followingDue(), DateTime(2026, 6, 10));
    });

    test('дата окончания раньше следующего платежа', () {
      final s = schedule(DateTime(2026, 5, 10), ends: DateTime(2026, 6, 9));
      expect(s.followingDue(), isNull);
    });

    test('время в nextDueAt не влияет на результат', () {
      final s = schedule(DateTime(2026, 1, 31, 18, 45), anchor: 31);
      expect(s.followingDue(), DateTime(2026, 2, 28));
    });
  });

  group('просрочка и дни до платежа', () {
    final today = DateTime(2026, 10, 14, 15, 30);

    test('платёж сегодня не просрочен, до него 0 дней', () {
      final s = schedule(DateTime(2026, 10, 14));
      expect(s.isOverdue(today), isFalse);
      expect(s.daysUntilDue(today), 0);
    });

    test('вчерашний платёж просрочен', () {
      final s = schedule(DateTime(2026, 10, 13));
      expect(s.isOverdue(today), isTrue);
      expect(s.daysUntilDue(today), -1);
    });

    test('через 3 дня', () {
      final s = schedule(DateTime(2026, 10, 17));
      expect(s.isOverdue(today), isFalse);
      expect(s.daysUntilDue(today), 3);
    });

    test('переход на зимнее время не ломает счёт дней', () {
      final s = schedule(DateTime(2026, 11, 1));
      expect(s.daysUntilDue(DateTime(2026, 10, 24)), 8);
    });
  });

  group('remindOn', () {
    test('за 3 дня до платежа', () {
      expect(schedule(DateTime(2026, 3, 2)).remindOn(3), DateTime(2026, 2, 27));
    });

    test('в день платежа', () {
      expect(schedule(DateTime(2026, 3, 2)).remindOn(0), DateTime(2026, 3, 2));
    });
  });

  group('occurrencesBetween', () {
    test('ежемесячный платёж в пределах квартала', () {
      final s = schedule(DateTime(2026, 1, 15));
      final r = s
          .occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 3, 31))
          .toList();
      expect(r, [
        DateTime(2026, 1, 15),
        DateTime(2026, 2, 15),
        DateTime(2026, 3, 15),
      ]);
    });

    test('границы включаются', () {
      final s = schedule(DateTime(2026, 1, 15));
      final r = s
          .occurrencesBetween(DateTime(2026, 2, 15), DateTime(2026, 2, 15))
          .toList();
      expect(r, [DateTime(2026, 2, 15)]);
    });

    test('даты до nextDueAt не возвращаются', () {
      final s = schedule(DateTime(2026, 3, 10));
      final r = s
          .occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 3, 31))
          .toList();
      expect(r, [DateTime(2026, 3, 10)]);
    });

    test('окончание кредита обрезает список', () {
      final s = schedule(DateTime(2026, 1, 10), ends: DateTime(2026, 3, 10));
      final r = s
          .occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 12, 31))
          .toList();
      expect(r.length, 3);
      expect(r.last, DateTime(2026, 3, 10));
    });

    test('31-е: даты по месяцам с учётом короткого месяца', () {
      final s = schedule(DateTime(2026, 1, 31));
      final r = s
          .occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 4, 30))
          .toList();
      expect(r, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('годовой платёж: в отрезке без даты пусто', () {
      final s = schedule(DateTime(2026, 9, 1), period: 12);
      final r = s
          .occurrencesBetween(DateTime(2026, 10, 1), DateTime(2027, 8, 31))
          .toList();
      expect(r, isEmpty);
    });

    test('отрезок, целиком раньше платежа, пуст', () {
      final s = schedule(DateTime(2026, 6, 1));
      final r = s
          .occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 2, 28))
          .toList();
      expect(r, isEmpty);
    });
  });

  group('forecastForMonth', () {
    final month = DateTime(2026, 10, 20);

    test('суммирует известные суммы и считает переменные отдельно', () {
      final f = forecastForMonth([
        (schedule: schedule(DateTime(2026, 10, 5)), amountKopecks: 59900),
        (schedule: schedule(DateTime(2026, 10, 25)), amountKopecks: 120000),
        (schedule: schedule(DateTime(2026, 10, 12)), amountKopecks: null),
      ], month);
      expect(f.totalKopecks, 179900);
      expect(f.variableCount, 1);
      expect(f.paymentsCount, 3);
    });

    test('платёж другого месяца не учитывается', () {
      final f = forecastForMonth([
        (
          schedule: schedule(DateTime(2026, 9, 5), period: 12),
          amountKopecks: 100000,
        ),
      ], month);
      expect(f.totalKopecks, 0);
      expect(f.paymentsCount, 0);
    });

    test('закончившийся кредит не попадает в прогноз', () {
      final f = forecastForMonth([
        (
          schedule: schedule(
            DateTime(2026, 8, 10),
            ends: DateTime(2026, 9, 10),
          ),
          amountKopecks: 500000,
        ),
      ], month);
      expect(f.paymentsCount, 0);
    });

    test('пустой список', () {
      final f = forecastForMonth(const [], month);
      expect(f.totalKopecks, 0);
      expect(f.variableCount, 0);
      expect(f.paymentsCount, 0);
    });
  });
}
