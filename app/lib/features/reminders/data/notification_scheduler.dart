import '../domain/reminder_planner.dart';

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

  /// Платежи, по уведомлениям о которых нажал пользователь, пока приложение
  /// было запущено.
  Stream<int> get tappedPayments;

  /// Платёж из уведомления, по нажатию на которое запустилось приложение;
  /// null при обычном запуске. Вызывается один раз при старте.
  Future<int?> launchedByPayment();

  /// Показывает тестовое уведомление через [after].
  Future<void> scheduleTest({
    required Duration after,
    required String title,
    required String body,
  });
}
