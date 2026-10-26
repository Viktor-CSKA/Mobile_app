import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reminders/data/reminder_providers.dart';

/// Показывать ли платежи по категориям (иначе одним списком по дате).
/// Выбор запоминается на устройстве.
class PaymentsGroupingNotifier extends Notifier<bool> {
  static const key = 'payments_group_by_category';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> set(bool groupByCategory) async {
    state = groupByCategory;
    await ref.read(sharedPreferencesProvider).setBool(key, groupByCategory);
  }
}

final paymentsGroupingProvider =
    NotifierProvider<PaymentsGroupingNotifier, bool>(
      PaymentsGroupingNotifier.new,
    );
