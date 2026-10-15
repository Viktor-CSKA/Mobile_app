import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/clock.dart';
import '../../payments/data/payments_providers.dart';
import '../domain/reminder_planner.dart';
import 'local_notification_scheduler.dart';
import 'notification_scheduler.dart';
import 'reminder_service.dart';
import 'settings_store.dart';

/// Подставляется в `main()` (и в тестах) уже загруженным экземпляром.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider не задан'),
);

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => LocalNotificationScheduler(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(ref.watch(notificationSchedulerProvider)),
);

final reminderSettingsStoreProvider = Provider<ReminderSettingsStore>(
  (ref) => ReminderSettingsStore(ref.watch(sharedPreferencesProvider)),
);

class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() => ref.watch(reminderSettingsStoreProvider).load();

  Future<void> setEnabled(bool enabled) =>
      _update(state.copyWith(enabled: enabled));

  Future<void> setMinutesOfDay(int minutes) =>
      _update(state.copyWith(minutesOfDay: minutes));

  Future<void> _update(ReminderSettings next) async {
    state = next;
    await ref.read(reminderSettingsStoreProvider).save(next);
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

/// Следит за платежами и настройками и пересчитывает уведомления.
/// Подключается один раз в корне приложения.
final reminderSyncProvider = Provider<void>((ref) {
  void run() {
    final payments = ref.read(activePaymentsProvider).value;
    if (payments == null) return;
    // «Сейчас» читается заново: приложение могло долго быть открытым, и
    // закэшированное время дало бы напоминания «в прошлом».
    ref.invalidate(nowProvider);
    ref
        .read(reminderServiceProvider)
        .sync(
          payments: payments,
          settings: ref.read(reminderSettingsProvider),
          now: ref.read(nowProvider),
        )
        .catchError((Object e) {
          debugPrint('Не удалось обновить напоминания: $e');
        });
  }

  ref.listen(activePaymentsProvider, (_, _) => run());
  ref.listen(reminderSettingsProvider, (_, _) => run());
  run();
});

/// Состояние разрешений для экрана настроек.
typedef NotificationStatus = ({bool notifications, bool exactAlarms});

final notificationStatusProvider =
    FutureProvider.autoDispose<NotificationStatus>((ref) async {
      final scheduler = ref.watch(notificationSchedulerProvider);
      return (
        notifications: await scheduler.notificationsAllowed(),
        exactAlarms: await scheduler.exactAlarmsAllowed(),
      );
    });
