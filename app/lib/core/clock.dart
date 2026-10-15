import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/payments/domain/payment_schedule.dart';

/// Текущий момент. В тестах подменяется фиксированным.
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Сегодняшний день (без времени). В тестах подменяется фиксированной датой.
final todayProvider = Provider<DateTime>((ref) => dateOnly(DateTime.now()));
