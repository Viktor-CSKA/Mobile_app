import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/calendar/presentation/calendar_screen.dart';
import 'features/payments/data/payments_providers.dart';
import 'features/payments/presentation/payment_form_screen.dart';
import 'features/payments/presentation/payments_screen.dart';
import 'features/reminders/data/reminder_providers.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/upcoming/presentation/upcoming_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  StreamSubscription<int>? _taps;

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
    // Нажатие на напоминание открывает платёж: и когда приложение уже
    // работает, и когда оно запущено самим уведомлением.
    _taps = scheduler.tappedPayments.listen(_openPayment);
    scheduler
        .launchedByPayment()
        .then((id) {
          if (id != null) _openPayment(id);
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

  Future<void> _openPayment(int id) async {
    final payment = await ref.read(paymentsRepositoryProvider).getById(id);
    if (!mounted) return;
    if (payment == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Этот платёж уже удалён')));
      return;
    }
    // Под формой оставляем «Ближайшие»: закрыв платёж, пользователь окажется
    // там, где отмечают оплату.
    setState(() => _index = 0);
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => PaymentFormScreen(paymentId: id)),
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
