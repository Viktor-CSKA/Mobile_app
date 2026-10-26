import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format_ru.dart';
import '../../payments/data/payments_providers.dart';
import '../../payments/domain/payment_draft.dart';
import 'pay_dialog.dart';

/// Отмечает платёж оплаченным и показывает снэкбар с кнопкой «Отменить».
///
/// По умолчанию спрашивает сумму. С [askKnownAmount] = false платёж с
/// постоянной суммой отмечается сразу (кнопка «Оплачено» на уведомлении):
/// ошибку исправляет «Отменить». Для переменной суммы спрашивают всегда.
Future<void> payPayment(
  BuildContext context,
  WidgetRef ref,
  PaymentWithCategory item, {
  bool askKnownAmount = true,
}) async {
  final known = item.payment.amountKopecks;
  final int? amount = (!askKnownAmount && known != null)
      ? known
      : await showPayDialog(context, item);
  if (amount == null || !context.mounted) return;

  final repo = ref.read(paymentsRepositoryProvider);
  final result = await repo.markPaid(item.payment.id, amountKopecks: amount);
  if (!context.mounted) return;

  final name = item.payment.name;
  final next = result.nextDue;
  final text = next == null
      ? '«$name» оплачен. Платёж завершён.'
      : '«$name» оплачен. Следующий: ${formatDayMonthShort(next)}.';
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 8),
        // Со кнопкой снэкбар по умолчанию не исчезает сам и закрывал бы
        // содержимое экрана; отмена нужна только на несколько секунд.
        persist: false,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            final ok = await repo.undoPaid(result);
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Оплата «$name» отменена'
                        : 'Отменить не получилось: платёж уже изменён',
                  ),
                ),
              );
          },
        ),
      ),
    );
}
