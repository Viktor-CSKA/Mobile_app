import '../../../core/database/app_database.dart';
import 'payment_schedule.dart';

/// Данные платежа, введённые пользователем (до сохранения в базу).
class PaymentDraft {
  const PaymentDraft({
    required this.name,
    required this.categoryId,
    required this.nextDueAt,
    this.amountKopecks,
    this.periodMonths = 1,
    this.remindDaysBefore = 1,
    this.endsAt,
    this.note = '',
  });

  final String name;
  final int categoryId;

  /// null — переменная сумма (например, ЖКХ).
  final int? amountKopecks;
  final int periodMonths;
  final DateTime nextDueAt;
  final int remindDaysBefore;
  final DateTime? endsAt;
  final String note;
}

/// Платёж вместе с категорией — то, что показывают в списках.
class PaymentWithCategory {
  const PaymentWithCategory(this.payment, this.category);

  final Payment payment;
  final Category category;

  PaymentSchedule get schedule => payment.schedule;
}

/// Итог отметки «Оплачено»: новая дата и всё нужное, чтобы отменить оплату.
class PaidResult {
  const PaidResult({
    required this.recordId,
    required this.paymentId,
    required this.previousDue,
    required this.wasActive,
    required this.nextDue,
  });

  /// Запись, добавленная в историю оплат.
  final int recordId;
  final int paymentId;

  /// Состояние платежа до оплаты.
  final DateTime previousDue;
  final bool wasActive;

  /// Новая ближайшая дата; null — платёж закончился.
  final DateTime? nextDue;
}

/// Оплата из истории вместе с платежом и его категорией.
class PaidEntry {
  const PaidEntry(this.record, this.payment, this.category);

  final PaymentRecord record;
  final Payment payment;
  final Category category;
}

extension PaymentScheduleX on Payment {
  PaymentSchedule get schedule => PaymentSchedule(
    nextDueAt: nextDueAt,
    anchorDay: anchorDay,
    periodMonths: periodMonths,
    endsAt: endsAt,
  );
}
