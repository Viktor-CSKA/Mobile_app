import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/data/payments_providers.dart';
import '../domain/year_stats.dart';

/// Итоги оплат за год; обновляются, когда меняется история оплат.
final yearStatsProvider = StreamProvider.family<YearStats, int>((ref, year) {
  return ref
      .watch(paymentsRepositoryProvider)
      .watchPaidBetween(DateTime(year), DateTime(year, 12, 31))
      .map((paid) => YearStats.build(year, paid));
});
