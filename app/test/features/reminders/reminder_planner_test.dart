import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/reminders/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = Category(id: 1, name: 'Подписки', colorValue: 0xFF8E24AA);

PaymentWithCategory pay(
  int id,
  DateTime due, {
  String? name,
  int? amount = 69000,
  int period = 1,
  int remind = 1,
  int? anchor,
  DateTime? ends,
  bool active = true,
}) => PaymentWithCategory(
  Payment(
    id: id,
    name: name ?? 'Платёж $id',
    categoryId: 1,
    amountKopecks: amount,
    periodMonths: period,
    nextDueAt: due,
    anchorDay: anchor ?? due.day,
    remindDaysBefore: remind,
    endsAt: ends,
    note: '',
    isActive: active,
  ),
  _category,
);

final now = DateTime(2026, 10, 15, 8, 0);

List<PlannedReminder> plan(
  List<PaymentWithCategory> items, {
  DateTime? at,
  int minutes = 9 * 60,
  int horizon = 90,
  int perPayment = 3,
  int total = 100,
}) => planReminders(
  payments: items,
  now: at ?? now,
  minutesOfDay: minutes,
  horizonDays: horizon,
  maxPerPayment: perPayment,
  maxTotal: total,
);

void main() {
  group('напоминание заранее', () {
    test('за день до платежа в 09:00', () {
      final r = plan([pay(1, DateTime(2026, 10, 20))]);
      expect(r.first.fireAt, DateTime(2026, 10, 19, 9, 0));
      expect(r.first.dueDate, DateTime(2026, 10, 20));
      expect(r.first.title, 'Платёж 1');
      expect(r.first.body, 'Завтра платёж · 690 ₽');
    });

    test('за несколько дней', () {
      final r = plan([pay(1, DateTime(2026, 10, 25), remind: 3)]);
      expect(r.first.fireAt, DateTime(2026, 10, 22, 9, 0));
      expect(r.first.body, 'Через 3 дн. платёж · 690 ₽');
    });

    test('в день платежа, если напоминать за 0 дней', () {
      final r = plan([pay(1, DateTime(2026, 10, 20), remind: 0)]);
      expect(r.first.fireAt, DateTime(2026, 10, 20, 9, 0));
      expect(r.first.body, 'Сегодня платёж · 690 ₽');
    });

    test('переход через границу месяца', () {
      final r = plan([pay(1, DateTime(2026, 11, 1))]);
      expect(r.first.fireAt, DateTime(2026, 10, 31, 9, 0));
    });

    test('выбранное время суток', () {
      final r = plan([pay(1, DateTime(2026, 10, 20))], minutes: 8 * 60 + 30);
      expect(r.first.fireAt, DateTime(2026, 10, 19, 8, 30));
    });

    test('переменная сумма', () {
      final r = plan([pay(1, DateTime(2026, 10, 20), amount: null)]);
      expect(r.first.body, 'Завтра платёж · сумма меняется');
    });
  });

  group('время напоминания уже прошло', () {
    test(
      'срок «за 3 дня» прошёл, платёж через 2 дня — напомним в день платежа',
      () {
        final r = plan([pay(1, DateTime(2026, 10, 17), remind: 3)]);
        expect(r.first.fireAt, DateTime(2026, 10, 17, 9, 0));
        expect(r.first.body, 'Сегодня платёж · 690 ₽');
      },
    );

    test('платёж сегодня, 09:00 ещё впереди — напомним сегодня', () {
      final r = plan([pay(1, DateTime(2026, 10, 15))]);
      expect(r.first.fireAt, DateTime(2026, 10, 15, 9, 0));
      expect(r.first.body, 'Сегодня платёж · 690 ₽');
    });

    test('платёж сегодня, 09:00 уже прошло — этого платежа не планируем', () {
      final r = plan([
        pay(1, DateTime(2026, 10, 15)),
      ], at: DateTime(2026, 10, 15, 10, 0));
      expect(r.map((e) => e.dueDate), isNot(contains(DateTime(2026, 10, 15))));
      // Но следующий ежемесячный платёж запланирован.
      expect(r.first.dueDate, DateTime(2026, 11, 15));
    });

    test('«за 0 дней» и время прошло — пропускаем', () {
      final r = plan([
        pay(1, DateTime(2026, 10, 15), remind: 0),
      ], at: DateTime(2026, 10, 15, 10, 0));
      expect(r.first.dueDate, DateTime(2026, 11, 15));
    });

    test('ровно в момент срабатывания — уже не планируем', () {
      final r = plan([
        pay(1, DateTime(2026, 10, 16)),
      ], at: DateTime(2026, 10, 15, 9, 0));
      // Напоминание «за день» = сегодня 09:00, это не позже now; ждём день платежа.
      expect(r.first.fireAt, DateTime(2026, 10, 16, 9, 0));
    });
  });

  group('просроченные', () {
    test('одно напоминание сегодня, если время ещё не прошло', () {
      final r = plan([pay(1, DateTime(2026, 10, 10))]);
      final overdue = r.firstWhere(
        (e) => e.id == 1 * 1000 + overdueReminderIndex,
      );
      expect(overdue.fireAt, DateTime(2026, 10, 15, 9, 0));
      expect(overdue.body, 'Просрочено на 5 дн. · 690 ₽');
      expect(overdue.dueDate, DateTime(2026, 10, 10));
    });

    test('время прошло — напоминание переносится на завтра', () {
      final r = plan([
        pay(1, DateTime(2026, 10, 10)),
      ], at: DateTime(2026, 10, 15, 10, 0));
      final overdue = r.firstWhere(
        (e) => e.id == 1 * 1000 + overdueReminderIndex,
      );
      expect(overdue.fireAt, DateTime(2026, 10, 16, 9, 0));
      expect(overdue.body, 'Просрочено на 6 дн. · 690 ₽');
    });

    test('у просроченного платежа остаются и будущие напоминания', () {
      final r = plan([pay(1, DateTime(2026, 10, 10))]);
      expect(r.length, 4); // просрочка + ноябрь, декабрь, январь
      expect(r.where((e) => e.id != 1999).map((e) => e.dueDate), [
        DateTime(2026, 11, 10),
        DateTime(2026, 12, 10),
        DateTime(2027, 1, 10),
      ]);
    });

    test('не просроченный платёж без напоминания о просрочке', () {
      final r = plan([pay(1, DateTime(2026, 10, 20))]);
      expect(r.where((e) => e.id == 1999), isEmpty);
    });
  });

  group('горизонт и ограничения', () {
    test('не больше трёх ближайших дат на платёж', () {
      final r = plan([pay(1, DateTime(2026, 10, 20))], horizon: 400);
      expect(r.length, 3);
      expect(r.map((e) => e.id), [1000, 1001, 1002]);
    });

    test('ограничение на платёж настраивается', () {
      final r = plan([pay(1, DateTime(2026, 10, 20))], perPayment: 1);
      expect(r.length, 1);
    });

    test('дальше горизонта не планируем', () {
      final yearly = pay(1, DateTime(2027, 5, 1), period: 12);
      expect(plan([yearly]), isEmpty);
      expect(plan([yearly], horizon: 400), isNotEmpty);
    });

    test('годовой платёж в пределах горизонта', () {
      final r = plan([pay(1, DateTime(2026, 12, 5), period: 12)]);
      expect(r.single.fireAt, DateTime(2026, 12, 4, 9, 0));
    });

    test('окончание кредита обрывает список', () {
      final loan = pay(1, DateTime(2026, 10, 20), ends: DateTime(2026, 11, 20));
      final r = plan([loan]);
      expect(r.map((e) => e.dueDate), [
        DateTime(2026, 10, 20),
        DateTime(2026, 11, 20),
      ]);
    });

    test('неактивные платежи пропускаются', () {
      expect(plan([pay(1, DateTime(2026, 10, 20), active: false)]), isEmpty);
    });

    test('пустой список', () {
      expect(plan(const []), isEmpty);
    });

    test('общий предел оставляет самые ближайшие по времени', () {
      final items = [
        pay(1, DateTime(2026, 10, 30)),
        pay(2, DateTime(2026, 10, 20)),
        pay(3, DateTime(2026, 10, 25)),
      ];
      final r = plan(items, total: 2, perPayment: 1);
      expect(r.map((e) => e.paymentId), [2, 3]);
    });
  });

  group('порядок и идентификаторы', () {
    test('отсортировано по времени срабатывания', () {
      final r = plan([
        pay(1, DateTime(2026, 10, 30)),
        pay(2, DateTime(2026, 10, 20)),
      ], perPayment: 1);
      expect(r.map((e) => e.paymentId), [2, 1]);
    });

    test('идентификаторы уникальны и стабильны', () {
      final items = [
        pay(1, DateTime(2026, 10, 10)),
        pay(2, DateTime(2026, 10, 20)),
        pay(15, DateTime(2026, 10, 22)),
      ];
      final a = plan(items);
      final b = plan(items);
      expect(a.map((e) => e.id).toSet().length, a.length);
      expect(a.map((e) => e.id), b.map((e) => e.id));
    });

    test('31-е: февраль даёт 28-е и напоминание 27-го', () {
      final r = plan(
        [pay(1, DateTime(2027, 1, 31), anchor: 31)],
        at: DateTime(2027, 1, 1, 8),
        horizon: 60,
      );
      expect(r.map((e) => e.fireAt), [
        DateTime(2027, 1, 30, 9, 0),
        DateTime(2027, 2, 27, 9, 0),
      ]);
    });
  });

  group('ReminderSettings', () {
    test('значения по умолчанию', () {
      const s = ReminderSettings();
      expect(s.enabled, isTrue);
      expect(s.minutesOfDay, 540);
    });

    test('copyWith и равенство', () {
      const s = ReminderSettings();
      expect(s.copyWith(enabled: false).enabled, isFalse);
      expect(s.copyWith(minutesOfDay: 600).minutesOfDay, 600);
      expect(s.copyWith(), s);
      expect(s.copyWith(enabled: false), isNot(s));
      expect(s.hashCode, const ReminderSettings().hashCode);
    });
  });
}
