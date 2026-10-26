import '../../../core/database/app_database.dart';
import '../../payments/domain/payment_draft.dart';

/// Сколько оплачено в одной категории.
class CategoryTotal {
  const CategoryTotal(this.category, this.kopecks);

  final Category category;
  final int kopecks;
}

/// Итоги оплат за календарный год по истории оплат («Оплачено»).
class YearStats {
  const YearStats._({
    required this.year,
    required this.totalKopecks,
    required this.paymentsCount,
    required this.byMonthKopecks,
    required this.byCategory,
  });

  /// Считает итоги за [year]. Оплаты других лет пропускаются.
  factory YearStats.build(int year, Iterable<PaidEntry> paid) {
    final months = List<int>.filled(12, 0);
    final byCategory = <int, int>{};
    final categories = <int, Category>{};
    var total = 0;
    var count = 0;
    for (final entry in paid) {
      final at = entry.record.paidAt;
      if (at.year != year) continue;
      final amount = entry.record.amountKopecks;
      months[at.month - 1] += amount;
      byCategory[entry.category.id] =
          (byCategory[entry.category.id] ?? 0) + amount;
      categories[entry.category.id] = entry.category;
      total += amount;
      count++;
    }
    final list = [
      for (final e in byCategory.entries)
        CategoryTotal(categories[e.key]!, e.value),
    ]..sort((a, b) => b.kopecks.compareTo(a.kopecks));
    return YearStats._(
      year: year,
      totalKopecks: total,
      paymentsCount: count,
      byMonthKopecks: List.unmodifiable(months),
      byCategory: List.unmodifiable(list),
    );
  }

  final int year;
  final int totalKopecks;

  /// Сколько оплат отмечено за год.
  final int paymentsCount;

  /// Сумма по месяцам, январь первым (всегда 12 значений).
  final List<int> byMonthKopecks;

  /// Суммы по категориям, от большей к меньшей; категории без оплат не входят.
  final List<CategoryTotal> byCategory;

  bool get isEmpty => paymentsCount == 0;

  /// Самый «дорогой» месяц, для масштаба столбиков.
  int get maxMonthKopecks =>
      byMonthKopecks.fold(0, (max, v) => v > max ? v : max);
}
