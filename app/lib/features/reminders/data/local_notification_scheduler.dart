import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_planner.dart';
import 'notification_scheduler.dart';

/// Реализация на flutter_local_notifications (Android).
///
/// Моменты времени передаются как UTC-инстанты, поэтому база часовых поясов не
/// нужна: уведомление сработает ровно в заданную локальную минуту.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'payment_reminders';
  static const _channel = AndroidNotificationChannel(
    _channelId,
    'Напоминания о платежах',
    description: 'Напоминания о приближающихся платежах и подписках',
    importance: Importance.high,
  );
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Напоминания о платежах',
      channelDescription: 'Напоминания о приближающихся платежах и подписках',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Идентификатор тестового уведомления (не пересекается с платежами).
  static const _testId = 2000000000;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _ensureInit() => _init ??= _initialize();

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _android?.createNotificationChannel(_channel);
  }

  Future<AndroidScheduleMode> _mode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _schedule({
    required int id,
    required DateTime fireAt,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(fireAt, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: await _mode(),
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _ensureInit();
    await _plugin.cancelAllPendingNotifications();
    for (final r in reminders) {
      await _schedule(
        id: r.id,
        fireAt: r.fireAt,
        title: r.title,
        body: r.body,
        payload: '${r.paymentId}',
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInit();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<bool> requestNotificationPermission() async {
    await _ensureInit();
    return await _android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<bool> notificationsAllowed() async {
    await _ensureInit();
    return await _android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> exactAlarmsAllowed() async {
    await _ensureInit();
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<void> requestExactAlarms() async {
    await _ensureInit();
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> scheduleTest({
    required Duration after,
    required String title,
    required String body,
  }) async {
    await _ensureInit();
    await _schedule(
      id: _testId,
      fireAt: DateTime.now().add(after),
      title: title,
      body: body,
    );
  }
}
