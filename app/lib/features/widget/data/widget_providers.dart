import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../payments/data/payments_providers.dart';
import '../domain/widget_data.dart';
import 'widget_cache_writer.dart';
import 'widget_refresh.dart';

final widgetCacheWriterProvider = Provider<WidgetCacheWriter>(
  (ref) => const FileWidgetCacheWriter(),
);

final widgetRefreshProvider = Provider<WidgetRefresh>(
  (ref) => const MethodChannelWidgetRefresh(),
);

/// Пересчитывает виджет при изменении платежей и при смене «сегодня».
///
/// Подключён в `app.dart` рядом с `reminderSyncProvider`; перечитывает время
/// при возврате в приложение (через `todayProvider`).
final widgetSyncProvider = Provider<void>((ref) {
  Future<void> run() async {
    final payments = ref.read(activePaymentsProvider).value;
    if (payments == null) return;
    final today = ref.read(todayProvider);
    final data = WidgetData.build(payments, today);
    try {
      await ref.read(widgetCacheWriterProvider).write(data);
      await ref.read(widgetRefreshProvider).refresh();
    } catch (_) {
      // Ошибки кэша или канала не должны мешать работе приложения.
    }
  }

  ref.listen(activePaymentsProvider, (_, _) => unawaited(run()));
  ref.listen(todayProvider, (_, _) => unawaited(run()));
  unawaited(run());
});
