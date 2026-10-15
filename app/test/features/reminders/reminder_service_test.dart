import 'dart:async';

import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/reminders/data/reminder_service.dart';
import 'package:ezhemesyachno/features/reminders/data/settings_store.dart';
import 'package:ezhemesyachno/features/reminders/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_scheduler.dart';

const _category = Category(id: 1, name: 'Подписки', colorValue: 0xFF8E24AA);

PaymentWithCategory pay(int id, DateTime due) => PaymentWithCategory(
  Payment(
    id: id,
    name: 'Платёж $id',
    categoryId: 1,
    amountKopecks: 10000,
    periodMonths: 1,
    nextDueAt: due,
    anchorDay: due.day,
    remindDaysBefore: 1,
    note: '',
    isActive: true,
  ),
  _category,
);

final now = DateTime(2026, 10, 15, 8);

void main() {
  late FakeNotificationScheduler scheduler;
  late ReminderService service;

  setUp(() {
    scheduler = FakeNotificationScheduler();
    service = ReminderService(scheduler);
  });

  group('ReminderService', () {
    test('включено: заменяет напоминания рассчитанным списком', () async {
      await service.sync(
        payments: [pay(1, DateTime(2026, 10, 20))],
        settings: const ReminderSettings(),
        now: now,
      );
      expect(scheduler.replaceCalls.length, 1);
      expect(scheduler.lastPlan.first.fireAt, DateTime(2026, 10, 19, 9));
      expect(scheduler.cancelAllCalls, 0);
    });

    test('выключено: отменяет всё и ничего не планирует', () async {
      await service.sync(
        payments: [pay(1, DateTime(2026, 10, 20))],
        settings: const ReminderSettings(enabled: false),
        now: now,
      );
      expect(scheduler.cancelAllCalls, 1);
      expect(scheduler.replaceCalls, isEmpty);
    });

    test('учитывает выбранное время суток', () async {
      await service.sync(
        payments: [pay(1, DateTime(2026, 10, 20))],
        settings: const ReminderSettings(minutesOfDay: 20 * 60 + 15),
        now: now,
      );
      expect(scheduler.lastPlan.first.fireAt, DateTime(2026, 10, 19, 20, 15));
    });

    test('без платежей очищает запланированное', () async {
      await service.sync(
        payments: const [],
        settings: const ReminderSettings(),
        now: now,
      );
      expect(scheduler.replaceCalls.single, isEmpty);
    });

    test('вызовы выполняются по очереди, итог — по последнему', () async {
      final gate = Completer<void>();
      var first = true;
      scheduler.onBeforeApply = () async {
        // Первый вызов «застрянет», пока второй не будет поставлен в очередь.
        if (first) {
          first = false;
          await gate.future;
        }
      };

      final a = service.sync(
        payments: [pay(1, DateTime(2026, 10, 20))],
        settings: const ReminderSettings(),
        now: now,
      );
      final b = service.sync(
        payments: [pay(2, DateTime(2026, 10, 22))],
        settings: const ReminderSettings(),
        now: now,
      );
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.replaceCalls, isEmpty); // оба ждут первый

      gate.complete();
      await Future.wait([a, b]);

      expect(scheduler.replaceCalls.length, 2);
      expect(scheduler.replaceCalls.first.map((e) => e.paymentId).toSet(), {1});
      expect(scheduler.lastPlan.map((e) => e.paymentId).toSet(), {2});
    });

    test('сбой не ломает очередь: следующий вызов выполняется', () async {
      scheduler.failReplace = true;
      await expectLater(
        service.sync(
          payments: [pay(1, DateTime(2026, 10, 20))],
          settings: const ReminderSettings(),
          now: now,
        ),
        throwsStateError,
      );

      scheduler.failReplace = false;
      await service.sync(
        payments: [pay(1, DateTime(2026, 10, 20))],
        settings: const ReminderSettings(),
        now: now,
      );
      expect(scheduler.replaceCalls.length, 1);
    });

    test('изменение списка после вызова не влияет на пересчёт', () async {
      final gate = Completer<void>();
      scheduler.onBeforeApply = () => gate.future;
      final list = [pay(1, DateTime(2026, 10, 20))];

      final f = service.sync(
        payments: list,
        settings: const ReminderSettings(),
        now: now,
      );
      list.clear();
      gate.complete();
      await f;

      expect(scheduler.lastPlan, isNotEmpty);
    });
  });

  group('ReminderSettingsStore', () {
    Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    test('значения по умолчанию', () async {
      final s = ReminderSettingsStore(await prefs()).load();
      expect(s.enabled, isTrue);
      expect(s.minutesOfDay, 540);
    });

    test('сохраняет и читает', () async {
      final p = await prefs();
      await ReminderSettingsStore(p).save(
        const ReminderSettings(enabled: false, minutesOfDay: 18 * 60 + 30),
      );

      final loaded = ReminderSettingsStore(p).load();
      expect(loaded.enabled, isFalse);
      expect(loaded.minutesOfDay, 18 * 60 + 30);
    });

    test('читает ранее записанные значения', () async {
      final p = await prefs({
        'reminders_enabled': false,
        'reminders_minutes_of_day': 480,
      });
      final s = ReminderSettingsStore(p).load();
      expect(s.enabled, isFalse);
      expect(s.minutesOfDay, 480);
    });

    test('испорченное время заменяется значением по умолчанию', () async {
      for (final bad in [-5, 24 * 60, 99999]) {
        final p = await prefs({'reminders_minutes_of_day': bad});
        expect(
          ReminderSettingsStore(p).load().minutesOfDay,
          540,
          reason: '$bad',
        );
      }
    });
  });
}
