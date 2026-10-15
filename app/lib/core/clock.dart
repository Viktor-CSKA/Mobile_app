import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/payments/domain/payment_schedule.dart';

/// Сегодняшний день (без времени). В тестах подменяется фиксированной датой.
final todayProvider = Provider<DateTime>((ref) => dateOnly(DateTime.now()));
