import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reminders/data/reminder_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Вернулись из системных настроек — перечитываем разрешения.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationStatusProvider);
    }
  }

  Future<void> _pickTime() async {
    final current = ref.read(reminderSettingsProvider).minutesOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: 'Время напоминаний',
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .setMinutesOfDay(picked.hour * 60 + picked.minute);
  }

  Future<void> _allowNotifications() async {
    await ref
        .read(notificationSchedulerProvider)
        .requestNotificationPermission();
    ref.invalidate(notificationStatusProvider);
  }

  Future<void> _allowExact() async {
    await ref.read(notificationSchedulerProvider).requestExactAlarms();
    ref.invalidate(notificationStatusProvider);
  }

  Future<void> _sendTest() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(notificationSchedulerProvider)
        .scheduleTest(
          after: const Duration(seconds: 10),
          title: 'Ежемесячно',
          body: 'Так будут выглядеть напоминания о платежах',
        );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Тестовое уведомление придёт через 10 секунд'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    final status = ref.watch(notificationStatusProvider).value;
    final minutes = settings.minutesOfDay;
    final time =
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const _SectionTitle('Напоминания'),
          SwitchListTile(
            title: const Text('Напоминать о платежах'),
            subtitle: const Text('Уведомление перед каждым платежом'),
            value: settings.enabled,
            onChanged: (v) =>
                ref.read(reminderSettingsProvider.notifier).setEnabled(v),
          ),
          ListTile(
            enabled: settings.enabled,
            title: const Text('Время напоминаний'),
            subtitle: const Text('Когда присылать уведомления'),
            trailing: Text(
              time,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: settings.enabled ? _pickTime : null,
          ),
          if (status != null && !status.notifications)
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Уведомления выключены'),
              subtitle: const Text(
                'Нажмите, чтобы разрешить показ уведомлений',
              ),
              onTap: _allowNotifications,
            ),
          if (status != null && status.notifications && !status.exactAlarms)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Точное время выключено'),
              subtitle: const Text(
                'Напоминания могут приходить с задержкой. Нажмите, чтобы включить',
              ),
              onTap: _allowExact,
            ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Проверить уведомление'),
            subtitle: const Text('Придёт через 10 секунд'),
            onTap: _sendTest,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Здесь будут экспорт и резервная копия'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
