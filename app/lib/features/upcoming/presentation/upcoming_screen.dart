import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../../core/format/plural_ru.dart';
import '../../payments/data/payments_providers.dart';
import '../../payments/domain/payment_draft.dart';
import '../../payments/presentation/payment_form_screen.dart';
import '../../payments/presentation/payment_labels.dart';
import '../domain/upcoming_summary.dart';
import 'pay_dialog.dart';
import 'upcoming_labels.dart';

class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    PaymentWithCategory item,
  ) async {
    final amount = await showPayDialog(context, item);
    if (amount == null || !context.mounted) return;
    final next = await ref
        .read(paymentsRepositoryProvider)
        .markPaid(item.payment.id, amountKopecks: amount);
    if (!context.mounted) return;
    final name = item.payment.name;
    final text = next == null
        ? '«$name» оплачен. Платёж завершён.'
        : '«$name» оплачен. Следующий: ${formatDayMonthShort(next)}.';
    ScaffoldMessenger.of(context)
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

    return Scaffold(
      appBar: AppBar(title: const Text('Ближайшие')),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Не удалось загрузить платежи: $e')),
        data: (items) {
          final summary = UpcomingSummary.build(items, today);
          if (summary.isEmpty) return const _EmptyState();
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _SummaryCard(summary: summary),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Платежей пока нет.\nДобавьте первый на вкладке «Платежи».',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final UpcomingSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final need = summary.needThisMonth;
    final overdue = summary.overdueForecast;

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
            const SizedBox(height: 4),
            Text(
              formatKopecks(need.totalKopecks),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(details.join(' · '), style: theme.textTheme.bodyMedium),
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

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Color(item.category.colorValue),
        child: Text(
          p.name.characters.first.toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(p.name),
      subtitle: Text(
        '${dueLabel(days)} · ${formatDayMonthShort(p.nextDueAt)} · '
        '${periodLabel(p.periodMonths)}',
        style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
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
}
