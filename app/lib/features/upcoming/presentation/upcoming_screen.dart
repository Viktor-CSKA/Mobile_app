import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../../core/format/plural_ru.dart';
import '../../../core/widgets/month_progress_ring.dart';
import '../../../home_shell.dart';
import '../../calendar/data/calendar_providers.dart';
import '../../payments/data/payments_providers.dart';
import '../../payments/domain/payment_draft.dart';
import '../../payments/domain/payment_schedule.dart';
import '../../payments/presentation/payment_form_screen.dart';
import '../../payments/presentation/payment_labels.dart';
import '../domain/upcoming_labels.dart';
import '../domain/upcoming_summary.dart';
import 'pay_flow.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    PaymentWithCategory item,
  ) => payPayment(context, ref, item);

  /// Отмечает оплаченными все платежи до выбранной даты (кнопка в AppBar).
  /// Платежи с переменной суммой пропускаются — их отмечают вручную.
  Future<void> _payUntilDate(BuildContext context, WidgetRef ref) async {
    final today = ref.read(todayProvider);
    final now = dateOnly(today);
    final endOfMonth = DateTime(
      now.year,
      now.month,
      daysInMonth(now.year, now.month),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: endOfMonth,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !context.mounted) return;

    final repo = ref.read(paymentsRepositoryProvider);
    final (marked, skipped) = await repo.markPaidUntil(picked, today);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final text = skipped == 0
        ? 'Отмечено оплаченными: ${paymentsCountLabel(marked)}'
        : 'Отмечено: ${paymentsCountLabel(marked)}. '
              'Пропущено с переменной суммой: $skipped — отметьте их вручную';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _edit(BuildContext context, int paymentId) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PaymentFormScreen(paymentId: paymentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final payments = ref.watch(activePaymentsProvider);
    final paidThisMonth = ref.watch(
      paidInMonthProvider(DateTime(today.year, today.month)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ближайшие'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ещё',
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'pay_until',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.done_all_outlined),
                  title: Text('Оплатить всё до даты'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'pay_until') _payUntilDate(context, ref);
            },
          ),
        ],
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Не удалось загрузить платежи: $e')),
        data: (items) {
          final summary = UpcomingSummary.build(items, today);
          if (summary.isEmpty) return const _EmptyState();
          // Оплачено в этом месяце — для кольца прогресса. Общий размер месяца =
          // оплаченное + оставшееся к оплате (с учётом просрочки).
          final paidKopecks = (paidThisMonth.value ?? const []).fold<int>(
            0,
            (sum, e) => sum + e.record.amountKopecks,
          );
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _SummaryCard(summary: summary, paidKopecks: paidKopecks),
              if (summary.overdue.isNotEmpty) ...[
                const _SectionHeader('Просрочено', isAlert: true),
                for (final item in summary.overdue)
                  _UpcomingTile(
                    item: item,
                    today: today,
                    onPay: () => _pay(context, ref, item),
                    onTap: () => _edit(context, item.payment.id),
                  ),
              ],
              if (summary.upcoming.isNotEmpty) ...[
                const _SectionHeader('Ближайшие'),
                for (final item in summary.upcoming)
                  _UpcomingTile(
                    item: item,
                    today: today,
                    onPay: () => _pay(context, ref, item),
                    onTap: () => _edit(context, item.payment.id),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Платежей пока нет',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте первый платёж: подписку, ЖКХ или кредит —\n'
              'и увидите, сколько платить в этом месяце',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => HomeShell.goToTab(context, 2),
              icon: const Icon(Icons.add),
              label: const Text('Добавить платёж'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.paidKopecks});

  final UpcomingSummary summary;

  /// Уже оплачено в этом месяце — для кольца прогресса.
  final int paidKopecks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final need = summary.needThisMonth;
    final overdue = summary.overdueForecast;

    // Общий размер месяца = оплаченное + оставшееся к оплате (с просрочкой).
    final totalMonth = paidKopecks + need.totalKopecks;

    final details = <String>[
      if (need.paymentsCount == 0)
        'В этом месяце платежей больше нет'
      else
        'К оплате: ${paymentsCountLabel(need.paymentsCount)}',
      if (need.variableCount > 0)
        'и ещё ${need.variableCount} с переменной суммой',
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Нужно в этом месяце', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                MonthProgressRing(
                  paidKopecks: paidKopecks,
                  totalKopecks: totalMonth,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatKopecks(need.totalKopecks),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.join(' · '),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (overdue.paymentsCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Просрочено: ${paymentsCountLabel(overdue.paymentsCount)}'
                '${overdue.totalKopecks > 0 ? ' на ${formatKopecks(overdue.totalKopecks)}' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.isAlert = false});

  final String title;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: isAlert ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({
    required this.item,
    required this.today,
    required this.onPay,
    required this.onTap,
  });

  final PaymentWithCategory item;
  final DateTime today;
  final VoidCallback onPay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.payment;
    final days = item.schedule.daysUntilDue(today);
    final overdue = days < 0;
    final amount = p.amountKopecks;
    // Цвет срочности: просрочка — ошибка, близкие даты — акцент, остальное — нейтрально.
    final urgency = _urgencyColor(theme, days);

    return ListTile(
      onTap: onTap,
      leading: Container(
        // Кольцо срочности вокруг аватара категории.
        decoration: urgency == null
            ? null
            : BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: urgency, width: 2.5),
              ),
        padding: urgency == null ? null : const EdgeInsets.all(3),
        child: CircleAvatar(
          backgroundColor: Color(item.category.colorValue),
          child: Text(
            p.name.characters.first.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      title: Text(p.name),
      subtitle: Text(
        '${dueLabel(days)} · ${formatDayMonthShort(p.nextDueAt)} · '
        '${periodLabel(p.periodMonths)}',
        style: TextStyle(
          color: urgency ?? theme.colorScheme.onSurfaceVariant,
          fontWeight: overdue ? FontWeight.w600 : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            amount == null ? 'сумма меняется' : formatKopecks(amount),
            style: theme.textTheme.titleSmall,
          ),
          IconButton(
            tooltip: 'Оплачено',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: onPay,
          ),
        ],
      ),
    );
  }

  /// Цвет срочности по остатку дней; null — нейтральный (без выделения).
  Color? _urgencyColor(ThemeData theme, int days) {
    if (days < 0) return theme.colorScheme.error;
    if (days <= 2) return theme.colorScheme.tertiary;
    if (days <= 6) return theme.colorScheme.secondary;
    return null;
  }
}
