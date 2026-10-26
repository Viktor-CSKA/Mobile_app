import 'package:ezhemesyachno/features/reminders/data/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('данные уведомления: номер платежа и дата', () {
    expect(reminderPayload(7, DateTime(2026, 3, 5)), '7|2026-03-05');
  });

  test('разбор: номер и дата', () {
    final tap = parseReminderPayload('12|2026-10-20')!;
    expect(tap.paymentId, 12);
    expect(tap.dueDate, DateTime(2026, 10, 20));
    expect(tap.markPaid, isFalse);
  });

  test('разбор: признак кнопки «Оплачено» передаётся', () {
    expect(
      parseReminderPayload('3|2026-10-20', markPaid: true)!.markPaid,
      true,
    );
  });

  test('разбор: прежний формат (только номер)', () {
    final tap = parseReminderPayload('42')!;
    expect(tap.paymentId, 42);
    expect(tap.dueDate, isNull);
  });

  test('разбор: без данных и мусор — null', () {
    expect(parseReminderPayload(null), isNull);
    expect(parseReminderPayload(''), isNull);
    expect(parseReminderPayload('abc|2026-10-20'), isNull);
  });

  test('разбор: битая дата не мешает, даты просто нет', () {
    final tap = parseReminderPayload('5|не-дата')!;
    expect(tap.paymentId, 5);
    expect(tap.dueDate, isNull);
  });

  test('данные, собранные и разобранные обратно, совпадают', () {
    final tap = parseReminderPayload(
      reminderPayload(9, DateTime(2027, 1, 31)),
    )!;
    expect(tap.paymentId, 9);
    expect(tap.dueDate, DateTime(2027, 1, 31));
  });
}
