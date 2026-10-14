import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../data/payments_providers.dart';
import '../domain/payment_draft.dart';
import 'payment_form_screen.dart';
import 'payment_labels.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  void _openForm(BuildContext context, {int? paymentId}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PaymentFormScreen(paymentId: paymentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(activePaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Платежи')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Добавить платёж'),
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Не удалось загрузить платежи: $e')),
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _PaymentTile(
                  item: items[i],
                  onTap: () =>
                      _openForm(context, paymentId: items[i].payment.id),
                ),
              ),
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
          'Платежей пока нет.\nДобавьте подписку, ЖКХ, кредит или рассрочку.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.item, required this.onTap});

  final PaymentWithCategory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.payment;
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
        '${item.category.name} · ${periodLabel(p.periodMonths)} · '
        '${formatDayMonthShort(p.nextDueAt)}',
      ),
      trailing: Text(
        amount == null ? 'сумма меняется' : formatKopecks(amount),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
