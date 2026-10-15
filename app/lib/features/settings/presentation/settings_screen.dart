import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/plural_ru.dart';
import '../../backup/data/backup_providers.dart';
import '../../backup/data/data_transfer_service.dart';
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

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Выполняет экспорт и сообщает итог. Отказ пользователя ничего не показывает.
  Future<void> _transfer(
    Future<TransferResult> Function(DataTransferService service) action, {
    required String savedText,
  }) async {
    final result = await action(ref.read(dataTransferServiceProvider));
    if (!mounted) return;
    switch (result.status) {
      case TransferStatus.saved:
        _say(savedText);
      case TransferStatus.failed:
        _say(result.message ?? 'Не удалось выполнить операцию');
      case TransferStatus.cancelled || TransferStatus.restored:
        break;
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановить из копии?'),
        content: const Text(
          'Все текущие платежи и история оплат будут заменены данными из '
          'выбранного файла. Это действие нельзя отменить: при необходимости '
          'сначала сохраните резервную копию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выбрать файл'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(dataTransferServiceProvider)
        .restoreFromFile();
    if (!mounted) return;
    switch (result.status) {
      case TransferStatus.restored:
        _say(
          'Восстановлено: ${paymentsCountLabel(result.payments)}, '
          '${result.records} ${pluralRu(result.records, 'оплата', 'оплаты', 'оплат')}',
        );
      case TransferStatus.failed:
        _say('Файл не подошёл: ${result.message ?? 'неизвестная ошибка'}');
      case TransferStatus.cancelled || TransferStatus.saved:
        break;
    }
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
          const _SectionTitle('Данные'),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Сохранить резервную копию'),
            subtitle: const Text('Файл со всеми платежами и историей оплат'),
            onTap: () => _transfer(
              (s) => s.exportBackup(),
              savedText: 'Резервная копия сохранена',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Восстановить из копии'),
            subtitle: const Text('Заменит текущие данные содержимым файла'),
            onTap: _restore,
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Экспорт платежей (CSV)'),
            subtitle: const Text('Таблица для Excel'),
            onTap: () => _transfer(
              (s) => s.exportPaymentsCsv(),
              savedText: 'Таблица платежей сохранена',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Экспорт истории оплат (CSV)'),
            subtitle: const Text('Все отметки «Оплачено»'),
            onTap: () => _transfer(
              (s) => s.exportHistoryCsv(),
              savedText: 'История оплат сохранена',
            ),
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
