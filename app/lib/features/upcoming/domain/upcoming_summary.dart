import '../../payments/domain/payment_draft.dart';
import '../../payments/domain/payment_schedule.dart';

/// Данные вкладки «Ближайшие»: просроченное, ближайшее и сумма к оплате.
class UpcomingSummary {
  const UpcomingSummary({
    required this.overdue,
    required this.upcoming,
    required this.needThisMonth,
    required this.overdueForecast,
  });

  /// Просроченные платежи, самые старые сверху.
  final List<PaymentWithCategory> overdue;

  /// Остальные платежи по возрастанию даты.
  final List<PaymentWithCategory> upcoming;

  /// Сколько нужно заплатить до конца текущего месяца (с учётом просрочки).
  final MonthForecast needThisMonth;

  /// Только просроченное.
  final MonthForecast overdueForecast;

  bool get isEmpty => overdue.isEmpty && upcoming.isEmpty;

  factory UpcomingSummary.build(
    Iterable<PaymentWithCategory> items,
    DateTime today,
  ) {
    final now = dateOnly(today);
    int byDate(PaymentWithCategory a, PaymentWithCategory b) {
      final c = dateOnly(a.payment.nextDueAt)
          .compareTo(dateOnly(b.payment.nextDueAt));
      return c != 0 ? c : a.payment.name.compareTo(b.payment.name);
    }

    final active = items.where((e) => e.payment.isActive).toList()
      ..sort(byDate);
    final overdue = active.where((e) => e.schedule.isOverdue(now)).toList();
    final upcoming = active.where((e) => !e.schedule.isOverdue(now)).toList();

    Iterable<({PaymentSchedule schedule, int? amountKopecks})> asItems(
      Iterable<PaymentWithCategory> list,
    ) => list.map(
      (e) => (schedule: e.schedule, amountKopecks: e.payment.amountKopecks),
    );

    return UpcomingSummary(
      overdue: overdue,
      upcoming: upcoming,
      needThisMonth: forecastOutstanding(
        asItems(active),
        now,
        DateTime(now.year, now.month, daysInMonth(now.year, now.month)),
      ),
      // Только долги: платежи с датой от «сегодня» в отрезок не попадают.
      overdueForecast: forecastOutstanding(
        asItems(overdue),
        now,
        now.subtract(const Duration(days: 1)),
      ),
    );
  }
}
