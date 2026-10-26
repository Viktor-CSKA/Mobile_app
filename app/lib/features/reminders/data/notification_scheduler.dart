import '../domain/reminder_planner.dart';

/// Нажатие пользователя на напоминание о платеже.
class ReminderTap {
  const ReminderTap(this.paymentId, {this.markPaid = false, this.dueDate});

  final int paymentId;

  /// Дата платежа, о котором напомнило уведомление (null у напоминаний из
  /// прежних версий). Нужна, чтобы устаревшая кнопка «Оплачено» не отметила
  /// платёж второй раз.
  final DateTime? dueDate;

  /// true — нажата кнопка «Оплачено» на уведомлении, а не само уведомление.
  final bool markPaid;
}

/// Данные, которые кладутся в уведомление: «номер платежа|гггг-мм-дд».
String reminderPayload(int paymentId, DateTime dueDate) {
  final date =
      '${dueDate.year.toString().padLeft(4, '0')}-'
      '${dueDate.month.toString().padLeft(2, '0')}-'
      '${dueDate.day.toString().padLeft(2, '0')}';
  return '$paymentId|$date';
}

/// Разбор данных уведомления. Принимает и прежний формат (один номер платежа).
/// Для тестового уведомления без данных и для мусора возвращает null.
ReminderTap? parseReminderPayload(String? payload, {bool markPaid = false}) {
  if (payload == null) return null;
  final parts = payload.split('|');
  final id = int.tryParse(parts.first);
  if (id == null) return null;
  final due = parts.length > 1 ? DateTime.tryParse(parts[1]) : null;
  return ReminderTap(id, markPaid: markPaid, dueDate: due);
}

/// Платформенный слой уведомлений. В приложении — на flutter_local_notifications,
/// в тестах — подмена, поэтому вся логика остаётся проверяемой.
abstract class NotificationScheduler {
  /// Заменяет все запланированные напоминания переданными.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Отменяет все запланированные напоминания.
  Future<void> cancelAll();

  /// Просит у системы разрешение на показ уведомлений (Android 13+).
  /// Возвращает true, если разрешение есть.
  Future<bool> requestNotificationPermission();

  /// Разрешён ли показ уведомлений сейчас.
  Future<bool> notificationsAllowed();

  /// Разрешены ли точные будильники (Android 12+; без них уведомления
  /// приходят с небольшой задержкой).
  Future<bool> exactAlarmsAllowed();

  /// Открывает системные настройки, где пользователь включает точные будильники.
  Future<void> requestExactAlarms();

  /// Нажатия на напоминания (на само уведомление или на кнопку «Оплачено»),
  /// пока приложение было запущено.
  Stream<ReminderTap> get tappedPayments;

  /// Нажатие, по которому запустилось приложение; null при обычном запуске.
  /// Вызывается один раз при старте.
  Future<ReminderTap?> launchedByPayment();

  /// Показывает тестовое уведомление через [after].
  Future<void> scheduleTest({
    required Duration after,
    required String title,
    required String body,
  });
}
