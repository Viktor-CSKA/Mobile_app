import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/format/date_format_ru.dart';
import '../../../core/format/money.dart';
import '../../../core/format/plural_ru.dart';
import '../data/payments_providers.dart';

/// Сколько последних оплат показывать списком (остальные входят в итог).
const historyShownLimit = 12;

/// Итог по истории: сколько оплат и на какую сумму.
({int count, int totalKopecks}) historyTotals(List<PaymentRecord> records) => (
  count: records.length,
  totalKopecks: records.fold(0, (sum, r) => sum + r.amountKopecks),
);

/// Раздел «История оплат» в форме редактирования платежа.
class PaymentHistory extends ConsumerWidget {
  const PaymentHistory({super.key, required this.paymentId});

  final int paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final records = ref.watch(paymentRecordsProvider(paymentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('История оплат', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        records.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Не удалось загрузить историю: $e'),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'Оплат пока не было. Отметьте платёж на вкладке «Ближайшие».',
                style: theme.textTheme.bodyMedium,
              );
            }
            final totals = historyTotals(list);
            final shown = list.take(historyShownLimit);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всего оплачено: ${formatKopecks(totals.totalKopecks)} · '
                  '${totals.count} ${pluralRu(totals.count, 'оплата', 'оплаты', 'оплат')}',
                  style: theme.textTheme.bodyMedium,
                ),
                for (final r in shown)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(formatDateFull(r.paidAt)),
                    trailing: Text(
                      formatKopecks(r.amountKopecks),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                if (list.length > historyShownLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Показаны последние $historyShownLimit',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
