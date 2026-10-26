import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../data/payments_providers.dart';
import '../data/payments_view_providers.dart';
import '../domain/payment_draft.dart';
import '../domain/payments_view.dart';
import 'payment_form_screen.dart';
import 'payment_labels.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm({int? paymentId}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PaymentFormScreen(paymentId: paymentId),
      ),
    );
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _search.clear();
    });
  }

  AppBar _appBar(bool grouped) {
    if (_searching) {
      return AppBar(
        leading: IconButton(
          tooltip: 'Закрыть поиск',
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeSearch,
        ),
        title: TextField(
          controller: _search,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Поиск по названию',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_search.text.isNotEmpty)
            IconButton(
              tooltip: 'Очистить',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_search.clear),
            ),
        ],
      );
    }
    return AppBar(
      title: const Text('Платежи'),
      actions: [
        IconButton(
          tooltip: 'Поиск',
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searching = true),
        ),
        PopupMenuButton<bool>(
          tooltip: 'Вид списка',
          icon: const Icon(Icons.view_list_outlined),
          onSelected: (v) => ref.read(paymentsGroupingProvider.notifier).set(v),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: !grouped,
              checked: grouped,
              child: const Text('По категориям'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(activePaymentsProvider);
    final archived = ref.watch(archivedPaymentsProvider).value ?? const [];
    final grouped = ref.watch(paymentsGroupingProvider);
    final query = _searching ? _search.text : '';

    return Scaffold(
      appBar: _appBar(grouped),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Добавить платёж'),
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Не удалось загрузить платежи: $e')),
        data: (all) {
          if (all.isEmpty && archived.isEmpty) return const _EmptyState();
          final items = filterPayments(all, query);
          final shownArchived = filterPayments(archived, query);
          final searching = query.trim().isNotEmpty;

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (items.isEmpty && shownArchived.isEmpty && searching)
                const _Message('Ничего не найдено.')
              else if (items.isEmpty && !searching)
                const _Message('Активных платежей нет.'),
              if (grouped)
                for (final group in groupByCategory(items)) ...[
                  _GroupHeader(group),
                  for (final item in group.items) ...[
                    _PaymentTile(
                      item: item,
                      onTap: () => _openForm(paymentId: item.payment.id),
                    ),
                    const Divider(height: 1),
                  ],
                ]
              else
                for (final item in items) ...[
                  _PaymentTile(
                    item: item,
                    onTap: () => _openForm(paymentId: item.payment.id),
                  ),
                  const Divider(height: 1),
                ],
              if (shownArchived.isNotEmpty)
                ExpansionTile(
                  // При поиске совпадения в архиве раскрыты сразу.
                  key: ValueKey('archive-$searching'),
                  initiallyExpanded: searching,
                  leading: const Icon(Icons.archive_outlined),
                  title: Text('Архив · ${shownArchived.length}'),
                  subtitle: const Text('Выплаченные и убранные платежи'),
                  children: [
                    for (final item in shownArchived)
                      _PaymentTile(
                        item: item,
                        archived: true,
                        onTap: () => _openForm(paymentId: item.payment.id),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
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

/// Заголовок группы: цвет и название категории, число платежей и сумма.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.group);

  final CategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = group.knownTotalKopecks;
    final parts = [
      '${group.items.length}',
      if (total > 0) formatKopecks(total),
    ];
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: Color(group.category.colorValue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(group.category.name, style: theme.textTheme.titleSmall),
          ),
          Text(parts.join(' · '), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.item,
    required this.onTap,
    this.archived = false,
  });

  final PaymentWithCategory item;
  final VoidCallback onTap;

  /// Платёж из архива: без ближайшей даты, приглушённый цвет.
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final p = item.payment;
    final amount = p.amountKopecks;
    final subtitle = archived
        ? '${item.category.name} · ${periodLabel(p.periodMonths)}'
        : '${item.category.name} · ${periodLabel(p.periodMonths)} · '
              '${formatDayMonthShort(p.nextDueAt)}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Color(item.category.colorValue)
            .withValues(alpha: archived ? 0.5 : 1),
        child: Text(
          p.name.characters.first.toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(p.name),
      subtitle: Text(subtitle),
      trailing: Text(
        amount == null ? 'сумма меняется' : formatKopecks(amount),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
