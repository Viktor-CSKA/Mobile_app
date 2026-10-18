import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/payment_draft.dart';
import 'payments_repository.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(appDatabaseProvider)),
);

final activePaymentsProvider = StreamProvider<List<PaymentWithCategory>>(
  (ref) => ref.watch(paymentsRepositoryProvider).watchActive(),
);

/// Платежи в архиве (выплаченные и убранные вручную).
final archivedPaymentsProvider = StreamProvider<List<PaymentWithCategory>>(
  (ref) => ref.watch(paymentsRepositoryProvider).watchArchived(),
);

/// История оплат одного платежа, новые сверху.
final paymentRecordsProvider = StreamProvider.family<List<PaymentRecord>, int>(
  (ref, paymentId) =>
      ref.watch(paymentsRepositoryProvider).watchRecords(paymentId),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(paymentsRepositoryProvider).watchCategories(),
);
