import 'dart:math' as math;

/// Все даты в расписании считаются как «дата без времени» (локальный день).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Дата платежа в месяце [year]-[month] с днём [anchorDay]; если в месяце
/// меньше дней (31-е в феврале), берётся последний день месяца.
DateTime dueDateInMonth(int year, int month, int anchorDay) {
  assert(anchorDay >= 1 && anchorDay <= 31, 'anchorDay вне диапазона 1..31');
  return DateTime(year, month, math.min(anchorDay, daysInMonth(year, month)));
}

/// Следующая дата платежа через [periodMonths] месяцев после [current].
///
/// День берётся из [anchorDay] (исходного дня платежа), а не из [current],
/// иначе платёж «31-го» после февраля навсегда сдвинулся бы на 28-е.
DateTime nextDueDate({
  required DateTime current,
  required int anchorDay,
  required int periodMonths,
}) {
  assert(periodMonths >= 1, 'periodMonths должен быть не меньше 1');
  final total = current.year * 12 + (current.month - 1) + periodMonths;
  return dueDateInMonth(total ~/ 12, total % 12 + 1, anchorDay);
}

/// Расписание одного регулярного платежа.
class PaymentSchedule {
  const PaymentSchedule({
    required this.nextDueAt,
    required this.anchorDay,
    this.periodMonths = 1,
    this.endsAt,
  }) : assert(periodMonths >= 1),
       assert(anchorDay >= 1 && anchorDay <= 31);

  /// Ближайшая неоплаченная дата.
  final DateTime nextDueAt;

  /// Исходный день месяца (1..31).
  final int anchorDay;

  /// 1 — ежемесячно, 3 — раз в квартал, 12 — раз в год.
  final int periodMonths;

  /// Последний день платежа включительно (кредит, рассрочка); null — бессрочно.
  final DateTime? endsAt;

  DateTime get _due => dateOnly(nextDueAt);

  bool _afterEnd(DateTime d) =>
      endsAt != null && d.isAfter(dateOnly(endsAt as DateTime));

  /// Просрочен: дата прошла, а платёж не отмечен оплаченным.
  bool isOverdue(DateTime today) => _due.isBefore(dateOnly(today));

  /// Дней до платежа; отрицательное число — просрочка.
  int daysUntilDue(DateTime today) {
    final a = DateTime.utc(_due.year, _due.month, _due.day);
    final t = dateOnly(today);
    return a.difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  }

  /// День, когда нужно показать напоминание.
  DateTime remindOn(int remindDaysBefore) =>
      _due.subtract(Duration(days: remindDaysBefore));

  /// Дата следующего платежа после оплаты текущего; null — платёж закончился.
  DateTime? followingDue() {
    final next = nextDueDate(
      current: _due,
      anchorDay: anchorDay,
      periodMonths: periodMonths,
    );
    return _afterEnd(next) ? null : next;
  }

  /// Все даты платежа в отрезке [from]..[to] включительно, начиная с [nextDueAt].
  Iterable<DateTime> occurrencesBetween(DateTime from, DateTime to) sync* {
    final start = dateOnly(from);
    final end = dateOnly(to);
    var d = _due;
    while (!d.isAfter(end) && !_afterEnd(d)) {
      if (!d.isBefore(start)) yield d;
      d = nextDueDate(
        current: d,
        anchorDay: anchorDay,
        periodMonths: periodMonths,
      );
    }
  }
}

/// Прогноз платежей на месяц.
class MonthForecast {
  const MonthForecast({
    required this.totalKopecks,
    required this.variableCount,
    required this.paymentsCount,
  });

  /// Сумма платежей с известной суммой, в копейках.
  final int totalKopecks;

  /// Сколько платежей с переменной суммой (ЖКХ): они в сумму не входят.
  final int variableCount;

  /// Сколько всего платежей приходится на месяц.
  final int paymentsCount;
}

/// Сколько платежей и на какую сумму приходится на месяц [month].
MonthForecast forecastForMonth(
  Iterable<({PaymentSchedule schedule, int? amountKopecks})> items,
  DateTime month,
) {
  return _forecastBetween(
    items,
    DateTime(month.year, month.month),
    DateTime(month.year, month.month, daysInMonth(month.year, month.month)),
  );
}

/// Сколько нужно заплатить, начиная с [today] и до [through] включительно.
///
/// Просроченный платёж считается один раз (как долг), даже если просрочен на
/// несколько периодов: пропущенные ранее даты не накапливаются. Затем идут
/// платежи с датой от [today] до [through].
MonthForecast forecastOutstanding(
  Iterable<({PaymentSchedule schedule, int? amountKopecks})> items,
  DateTime today,
  DateTime through,
) {
  var total = 0;
  var variable = 0;
  var count = 0;
  void add(int? amount) {
    count++;
    if (amount == null) {
      variable++;
    } else {
      total += amount;
    }
  }

  for (final item in items) {
    if (item.schedule.isOverdue(today)) add(item.amountKopecks);
    for (final _ in item.schedule.occurrencesBetween(today, through)) {
      add(item.amountKopecks);
    }
  }
  return MonthForecast(
    totalKopecks: total,
    variableCount: variable,
    paymentsCount: count,
  );
}

MonthForecast _forecastBetween(
  Iterable<({PaymentSchedule schedule, int? amountKopecks})> items,
  DateTime from,
  DateTime to,
) {
  var total = 0;
  var variable = 0;
  var count = 0;
  for (final item in items) {
    for (final _ in item.schedule.occurrencesBetween(from, to)) {
      count++;
      final amount = item.amountKopecks;
      if (amount == null) {
        variable++;
      } else {
        total += amount;
      }
    }
  }
  return MonthForecast(
    totalKopecks: total,
    variableCount: variable,
    paymentsCount: count,
  );
}
