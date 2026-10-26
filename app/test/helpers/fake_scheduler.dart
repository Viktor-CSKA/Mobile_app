import 'dart:async';

import 'package:ezhemesyachno/features/reminders/data/notification_scheduler.dart';
import 'package:ezhemesyachno/features/reminders/domain/reminder_planner.dart';

/// Подмена платформенного слоя: запоминает вызовы, ничего не показывает.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({
    this.notificationsGranted = true,
    this.exactGranted = true,
  });

  bool notificationsGranted;
  bool exactGranted;

  final List<List<PlannedReminder>> replaceCalls = [];
  int cancelAllCalls = 0;
  int permissionRequests = 0;
  int exactRequests = 0;
  final List<Duration> testCalls = [];

  /// Если задан — вызывается в начале replaceAll/cancelAll (для проверки очереди).
  Future<void> Function()? onBeforeApply;

  /// Если true — replaceAll бросает ошибку.
  bool failReplace = false;

  /// Нажатия на уведомления во время работы приложения: [tap] и [tapPaid].
  final StreamController<ReminderTap> taps =
      StreamController<ReminderTap>.broadcast();

  /// Нажатие на само напоминание о платеже [paymentId].
  void tap(int paymentId, {DateTime? due}) =>
      taps.add(ReminderTap(paymentId, dueDate: due));

  /// Нажатие на кнопку «Оплачено» у напоминания.
  void tapPaid(int paymentId, {DateTime? due}) =>
      taps.add(ReminderTap(paymentId, markPaid: true, dueDate: due));

  /// Платёж, по уведомлению о котором «запущено» приложение (null — обычный
  /// запуск), и была ли нажата кнопка «Оплачено».
  int? launchPaymentId;
  bool launchMarkPaid = false;

  @override
  Stream<ReminderTap> get tappedPayments => taps.stream;

  @override
  Future<ReminderTap?> launchedByPayment() async => launchPaymentId == null
      ? null
      : ReminderTap(launchPaymentId!, markPaid: launchMarkPaid);

  List<PlannedReminder> get lastPlan =>
      replaceCalls.isEmpty ? const [] : replaceCalls.last;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await onBeforeApply?.call();
    if (failReplace) throw StateError('сбой планировщика');
    replaceCalls.add(List.of(reminders));
  }

  @override
  Future<void> cancelAll() async {
    await onBeforeApply?.call();
    cancelAllCalls++;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    return notificationsGranted;
  }

  @override
  Future<bool> notificationsAllowed() async => notificationsGranted;

  @override
  Future<bool> exactAlarmsAllowed() async => exactGranted;

  @override
  Future<void> requestExactAlarms() async {
    exactRequests++;
  }

  @override
  Future<void> scheduleTest({
    required Duration after,
    required String title,
    required String body,
  }) async {
    testCalls.add(after);
  }
}
