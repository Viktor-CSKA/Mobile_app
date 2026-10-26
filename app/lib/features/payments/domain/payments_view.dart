import '../../../core/database/app_database.dart';
import 'payment_draft.dart';

/// Для сравнения: нижний регистр, «ё» как «е», без лишних пробелов по краям.
String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();

/// Платежи, в названии (и заметке) которых есть [query]. Пустой запрос ничего
/// не отсеивает. Порядок сохраняется.
List<PaymentWithCategory> filterPayments(
  List<PaymentWithCategory> items,
  String query,
) {
  final q = _norm(query);
  if (q.isEmpty) return items;
  return [
    for (final item in items)
      if (_norm(item.payment.name).contains(q) ||
          _norm(item.payment.note).contains(q))
        item,
  ];
}

/// Платежи одной категории для показа списком с заголовком.
class CategoryGroup {
  const CategoryGroup(this.category, this.items);

  final Category category;
  final List<PaymentWithCategory> items;

  /// Сумма платежей с известной суммой, в копейках (за один период каждого).
  int get knownTotalKopecks =>
      items.fold(0, (sum, item) => sum + (item.payment.amountKopecks ?? 0));

  /// Сколько платежей без известной суммы (ЖКХ): в сумму они не входят.
  int get variableCount =>
      items.where((item) => item.payment.amountKopecks == null).length;
}

/// Раскладывает платежи по категориям. Группы идут в порядке категорий
/// (по номеру), внутри группы сохраняется исходный порядок (по дате).
/// Категории без платежей не показываются.
List<CategoryGroup> groupByCategory(List<PaymentWithCategory> items) {
  final byId = <int, List<PaymentWithCategory>>{};
  final categories = <int, Category>{};
  for (final item in items) {
    byId.putIfAbsent(item.category.id, () => []).add(item);
    categories[item.category.id] = item.category;
  }
  final ids = byId.keys.toList()..sort();
  return [for (final id in ids) CategoryGroup(categories[id]!, byId[id]!)];
}
