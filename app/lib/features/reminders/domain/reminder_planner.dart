import '../../../core/format/money.dart';
import '../../payments/domain/payment_draft.dart';
import '../../payments/domain/payment_schedule.dart';

/// Настройки напоминаний.
class ReminderSettings {
  const ReminderSettings({this.enabled = true, this.minutesOfDay = 9 * 60});

  final bool enabled;

  /// Во сколько напоминать: минут от полуночи (09:00 = 540).
  final int minutesOfDay;

  ReminderSettings copyWith({bool? enabled, int? minutesOfDay}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => Object.hash(enabled, minutesOfDay);
}

/// Одно запланированное уведомление.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.paymentId,
    required this.fireAt,
    required this.dueDate,
    required this.title,
    required this.body,
  });

  /// Стабильный идентификатор уведомления (платёж × 1000 + номер).
  final int id;
  final int paymentId;

  /// Когда показать (локальное время).
  final DateTime fireAt;

  /// Дата платежа, о котором напоминание.
  final DateTime dueDate;
  final String title;
  final String body;
}

/// Номер для напоминания «платёж просрочен» (обычные — 0..maxPerPayment-1).
const overdueReminderIndex = 999;

/// Строит список уведомлений для активных платежей.
///
/// * Для каждого платежа — ближайшие [maxPerPayment] дат в пределах
///   [horizonDays]; уведомление приходит за `remindDaysBefore` дней в
///   [minutesOfDay]. Если это время уже прошло, а платёж ещё впереди,
///   напоминание переносится на день платежа.
/// * Просроченный платёж получает одно напоминание: сегодня (если время ещё
///   не прошло) или завтра в то же время.
/// * В итоге не больше [maxTotal] ближайших по времени уведомлений.
List<PlannedReminder> planReminders({
  required Iterable<PaymentWithCategory> payments,
  required DateTime now,
  int minutesOfDay = 9 * 60,
  int horizonDays = 90,
  int maxPerPayment = 3,
  int maxTotal = 100,
}) {
  assert(maxPerPayment > 0 && maxPerPayment < overdueReminderIndex);
  final today = dateOnly(now);
  final horizonEnd = DateTime(today.year, today.month, today.day + horizonDays);

  DateTime at(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
    minutesOfDay ~/ 60,
    minutesOfDay % 60,
  );

  final result = <PlannedReminder>[];

  for (final item in payments) {
    final p = item.payment;
    if (!p.isActive) continue;
    final schedule = item.schedule;
    final amount = p.amountKopecks;
    final amountText = amount == null
        ? 'сумма меняется'
        : formatKopecks(amount);

    if (schedule.isOverdue(today)) {
      final todayAt = at(today);
      final fireAt = todayAt.isAfter(now)
          ? todayAt
          : at(DateTime(today.year, today.month, today.day + 1));
      final lateDays = daysBetween(dateOnly(p.nextDueAt), dateOnly(fireAt));
      result.add(
        PlannedReminder(
          id: p.id * 1000 + overdueReminderIndex,
          paymentId: p.id,
          fireAt: fireAt,
          dueDate: dateOnly(p.nextDueAt),
          title: p.name,
          body: 'Просрочено на $lateDays дн. · $amountText',
        ),
      );
    }

    var index = 0;
    for (final due in schedule.occurrencesBetween(today, horizonEnd)) {
      if (index >= maxPerPayment) break;
      final advance = at(
        DateTime(due.year, due.month, due.day - p.remindDaysBefore),
      );
      DateTime? fireAt;
      if (advance.isAfter(now)) {
        fireAt = advance;
      } else if (p.remindDaysBefore > 0 && at(due).isAfter(now)) {
        fireAt = at(due); // время «за N дней» прошло — напомним в день платежа
      }
      if (fireAt != null) {
        result.add(
          PlannedReminder(
            id: p.id * 1000 + index,
            paymentId: p.id,
            fireAt: fireAt,
            dueDate: due,
            title: p.name,
            body: '${_when(daysBetween(dateOnly(fireAt), due))} · $amountText',
          ),
        );
      }
      index++;
    }
  }

  result.sort((a, b) {
    final c = a.fireAt.compareTo(b.fireAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return result.length > maxTotal ? result.sublist(0, maxTotal) : result;
}

String _when(int daysAhead) {
  if (daysAhead <= 0) return 'Сегодня платёж';
  if (daysAhead == 1) return 'Завтра платёж';
  return 'Через $daysAhead дн. платёж';
}
