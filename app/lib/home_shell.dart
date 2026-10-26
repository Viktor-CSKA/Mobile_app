import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/calendar/presentation/calendar_screen.dart';
import 'features/payments/data/payments_providers.dart';
import 'features/payments/domain/payment_schedule.dart';
import 'features/payments/presentation/payment_form_screen.dart';
import 'features/payments/presentation/payments_screen.dart';
import 'features/reminders/data/notification_scheduler.dart';
import 'features/reminders/data/reminder_providers.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/upcoming/presentation/pay_flow.dart';
import 'features/upcoming/presentation/upcoming_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  StreamSubscription<ReminderTap>? _taps;

  static const _screens = <Widget>[
    UpcomingScreen(),
    CalendarScreen(),
    PaymentsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final scheduler = ref.read(notificationSchedulerProvider);
    // Нажатие на напоминание открывает платёж (кнопка «Оплачено» отмечает
    // оплату): и когда приложение уже работает, и когда оно запущено самим
    // уведомлением.
    _taps = scheduler.tappedPayments.listen(_handleTap);
    scheduler
        .launchedByPayment()
        .then((tap) {
          if (tap != null) _handleTap(tap);
        })
        .catchError((Object e) {
          debugPrint('Не удалось определить запуск из уведомления: $e');
        });
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _handleTap(ReminderTap tap) async {
    final item = await ref
        .read(paymentsRepositoryProvider)
        .getWithCategory(tap.paymentId);
    if (!mounted) return;
    if (item == null) {
      _say('Этот платёж уже удалён');
      return;
    }
    // Под всем остальным оставляем «Ближайшие»: после платежа пользователь
    // окажется там, где видны итоги месяца.
    setState(() => _index = 0);

    if (tap.markPaid) {
      // Устаревшая кнопка «Оплачено» не должна отметить платёж второй раз:
      // дата платежа с тех пор изменилась (оплатили в приложении) или
      // платёж убрали в архив.
      final due = tap.dueDate;
      final stale =
          !item.payment.isActive ||
          (due != null && dateOnly(item.payment.nextDueAt) != dateOnly(due));
      if (!stale) {
        await payPayment(context, ref, item, askKnownAmount: false);
        return;
      }
      _say('Этот платёж уже изменён: проверьте его в списке');
    }

    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PaymentFormScreen(paymentId: tap.paymentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'Ближайшие',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Календарь',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Платежи',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
