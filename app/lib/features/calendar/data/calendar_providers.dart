import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/data/payments_providers.dart';
import '../../payments/domain/payment_draft.dart';
import '../../payments/domain/payment_schedule.dart';

/// Оплаты за месяц, первый день которого передан ключом.
final paidInMonthProvider = StreamProvider.family<List<PaidEntry>, DateTime>((
  ref,
  month,
) {
  final first = DateTime(month.year, month.month);
  final last = DateTime(
    month.year,
    month.month,
    daysInMonth(month.year, month.month),
  );
  return ref.watch(paymentsRepositoryProvider).watchPaidBetween(first, last);
});
