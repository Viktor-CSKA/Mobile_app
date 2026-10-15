import '../../payments/domain/payment_draft.dart';
import '../../payments/domain/payment_schedule.dart';

/// Платёж на конкретном дне календаря: запланированный или уже оплаченный.
class CalendarEntry {
  const CalendarEntry({
    required this.date,
    required this.paymentId,
    required this.name,
    required this.categoryName,
    required this.colorValue,
    required this.paid,
    required this.amountKopecks,
    this.overdue = false,
  });

  final DateTime date;
  final int paymentId;
  final String name;
  final String categoryName;
  final int colorValue;

  /// true — оплата из истории (день — день оплаты), иначе запланированный платёж.
  final bool paid;

  /// null — сумма переменная и ещё не известна.
  final int? amountKopecks;

  /// Запланированный платёж, дата которого уже прошла.
  final bool overdue;
}

/// Платежи месяца, разложенные по дням.
class MonthCalendar {
  MonthCalendar._(this.month, this._byDay);

  /// Первое число месяца.
  final DateTime month;
  final Map<DateTime, List<CalendarEntry>> _byDay;

  /// Построить календарь месяца [month].
  ///
  /// [scheduled] — активные платежи (показываются на своих датах начиная с
  /// ближайшей неоплаченной), [paid] — оплаты из истории (на день оплаты).
  factory MonthCalendar.build({
    required DateTime month,
    required DateTime today,
    required Iterable<PaymentWithCategory> scheduled,
    required Iterable<PaidEntry> paid,
  }) {
    final first = DateTime(month.year, month.month);
    final last = DateTime(
      month.year,
      month.month,
      daysInMonth(month.year, month.month),
    );
    final now = dateOnly(today);
    final byDay = <DateTime, List<CalendarEntry>>{};

    for (final item in scheduled) {
      if (!item.payment.isActive) continue;
      for (final date in item.schedule.occurrencesBetween(first, last)) {
        byDay
            .putIfAbsent(date, () => [])
            .add(
              CalendarEntry(
                date: date,
                paymentId: item.payment.id,
                name: item.payment.name,
                categoryName: item.category.name,
                colorValue: item.category.colorValue,
                paid: false,
                amountKopecks: item.payment.amountKopecks,
                overdue: date.isBefore(now),
              ),
            );
      }
    }

    for (final entry in paid) {
      final date = dateOnly(entry.record.paidAt);
      if (date.isBefore(first) || date.isAfter(last)) continue;
      byDay
          .putIfAbsent(date, () => [])
          .add(
            CalendarEntry(
              date: date,
              paymentId: entry.payment.id,
              name: entry.payment.name,
              categoryName: entry.category.name,
              colorValue: entry.category.colorValue,
              paid: true,
              amountKopecks: entry.record.amountKopecks,
            ),
          );
    }

    for (final list in byDay.values) {
      list.sort((a, b) {
        if (a.paid != b.paid) return a.paid ? 1 : -1;
        return a.name.compareTo(b.name);
      });
    }
    return MonthCalendar._(first, byDay);
  }

  int get daysCount => daysInMonth(month.year, month.month);

  /// Сколько пустых клеток перед 1-м числом (неделя с понедельника).
  int get leadingBlanks => month.weekday - 1;

  List<CalendarEntry> entriesOn(DateTime day) =>
      _byDay[dateOnly(day)] ?? const [];

  bool hasEntries(DateTime day) => entriesOn(day).isNotEmpty;

  /// Запланировано (известные суммы), оплачено и число платежей с переменной суммой.
  ({int plannedKopecks, int paidKopecks, int variableCount}) get totals {
    var planned = 0;
    var paid = 0;
    var variable = 0;
    for (final entry in _byDay.values.expand((e) => e)) {
      final amount = entry.amountKopecks;
      if (entry.paid) {
        paid += amount ?? 0;
      } else if (amount == null) {
        variable++;
      } else {
        planned += amount;
      }
    }
    return (
      plannedKopecks: planned,
      paidKopecks: paid,
      variableCount: variable,
    );
  }
}

/// Первое число месяца, смещённого на [delta] месяцев.
DateTime shiftMonth(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);
