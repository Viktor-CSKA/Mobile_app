import '../../../core/format/money.dart';
import '../../../core/format/plural_ru.dart';
import '../../payments/domain/payment_draft.dart';
import '../../upcoming/domain/upcoming_summary.dart';
import '../../upcoming/domain/upcoming_labels.dart' as labels;

/// Данные домашнего экранного виджета: итог месяца и ближайшие платежи.
///
/// Собирается в Dart из тех же источников, что и «Ближайшие», сериализуется
/// в JSON-кэш и рисуется нативным `AppWidgetProvider` (без дублирования логики
/// в Kotlin). Все поля — готовые подписи, нативная сторона только рендерит.
class WidgetData {
  const WidgetData({
    required this.monthTotalLabel,
    required this.noteLabel,
    required this.overdueCount,
    required this.payments,
    required this.isEmpty,
  });

  /// «Сколько заплатить в этом месяце», например `3 450 ₽`.
  final String monthTotalLabel;

  /// Примечание: «5 платежей · 1 с переменной суммой · 2 просрочено».
  final String noteLabel;

  /// Сколько платежей просрочено (для акцента на виджете).
  final int overdueCount;

  /// Ближайшие платежи, не более [maxPayments], просроченные первыми.
  final List<WidgetPaymentItem> payments;

  /// true — платежей нет, виджет показывает подсказку «Добавьте платежи».
  final bool isEmpty;

  /// Сколько ближайших платежей показывает виджет.
  static const int maxPayments = 3;

  factory WidgetData.build(
    Iterable<PaymentWithCategory> items,
    DateTime today,
  ) {
    final summary = UpcomingSummary.build(items, today);
    final need = summary.needThisMonth;
    final totalLabel = formatKopecks(need.totalKopecks);

    final parts = <String>[paymentsCountLabel(need.paymentsCount)];
    if (need.variableCount > 0) {
      parts.add(
        '${need.variableCount} ${pluralRu(need.variableCount, 'с переменной суммой', 'с переменными суммами', 'с переменными суммами')}',
      );
    }
    if (summary.overdue.isNotEmpty) {
      final n = summary.overdue.length;
      parts.add('$n ${pluralRu(n, 'просрочен', 'просрочено', 'просрочено')}');
    }

    final nearest = [...summary.overdue, ...summary.upcoming]
        .take(maxPayments)
        .map((e) => WidgetPaymentItem.from(e, today))
        .toList(growable: false);

    return WidgetData(
      monthTotalLabel: totalLabel,
      noteLabel: parts.join(' · '),
      overdueCount: summary.overdue.length,
      payments: nearest,
      isEmpty: summary.isEmpty,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'monthTotalLabel': monthTotalLabel,
    'noteLabel': noteLabel,
    'overdueCount': overdueCount,
    'payments': payments.map((e) => e.toJson()).toList(),
    'isEmpty': isEmpty,
  };

  factory WidgetData.fromJson(Map<String, Object?> json) => WidgetData(
    monthTotalLabel: json['monthTotalLabel'] as String? ?? '',
    noteLabel: json['noteLabel'] as String? ?? '',
    overdueCount: json['overdueCount'] as int? ?? 0,
    payments: (json['payments'] as List<Object?>? ?? const [])
        .map((e) => WidgetPaymentItem.fromJson(e! as Map<String, Object?>))
        .toList(),
    isEmpty: json['isEmpty'] as bool? ?? false,
  );
}

/// Один ближайший платёж для виджета.
class WidgetPaymentItem {
  const WidgetPaymentItem({
    required this.name,
    required this.amountLabel,
    required this.dueLabel,
    required this.colorHex,
  });

  final String name;

  /// null — переменная сумма (например, ЖКХ).
  final String? amountLabel;

  /// «сегодня», «завтра», «через 3 дн.», «просрочено на 2 дн.».
  final String dueLabel;

  /// Цвет категории в виде `#RRGGBB`.
  final String colorHex;

  factory WidgetPaymentItem.from(PaymentWithCategory item, DateTime today) {
    final amount = item.payment.amountKopecks;
    return WidgetPaymentItem(
      name: item.payment.name,
      amountLabel: amount == null ? null : formatKopecks(amount),
      dueLabel: labels.dueLabel(item.schedule.daysUntilDue(today)),
      colorHex: colorToHex(item.category.colorValue),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'amountLabel': amountLabel,
    'dueLabel': dueLabel,
    'colorHex': colorHex,
  };

  factory WidgetPaymentItem.fromJson(Map<String, Object?> json) =>
      WidgetPaymentItem(
        name: json['name'] as String? ?? '',
        amountLabel: json['amountLabel'] as String?,
        dueLabel: json['dueLabel'] as String? ?? '',
        colorHex: json['colorHex'] as String? ?? '',
      );
}

/// `0xFF795548` → `#795548`.
String colorToHex(int colorValue) =>
    '#${(colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
