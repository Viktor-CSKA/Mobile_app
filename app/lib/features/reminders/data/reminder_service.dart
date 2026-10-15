import '../../payments/domain/payment_draft.dart';
import '../domain/reminder_planner.dart';
import 'notification_scheduler.dart';

/// Приводит запланированные уведомления в соответствие с платежами и настройками.
///
/// Вызовы выстраиваются в очередь: пересчёты идут строго друг за другом, и
/// последний из них всегда определяет итоговое состояние.
class ReminderService {
  ReminderService(this._scheduler);

  final NotificationScheduler _scheduler;
  Future<void> _tail = Future.value();

  Future<void> sync({
    required Iterable<PaymentWithCategory> payments,
    required ReminderSettings settings,
    required DateTime now,
  }) {
    // Снимок списка: исходный может измениться, пока пересчёт ждёт очереди.
    final snapshot = payments.toList();
    final run = _tail.then((_) => _apply(snapshot, settings, now));
    _tail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _apply(
    List<PaymentWithCategory> payments,
    ReminderSettings settings,
    DateTime now,
  ) {
    if (!settings.enabled) return _scheduler.cancelAll();
    return _scheduler.replaceAll(
      planReminders(
        payments: payments,
        now: now,
        minutesOfDay: settings.minutesOfDay,
      ),
    );
  }
}
