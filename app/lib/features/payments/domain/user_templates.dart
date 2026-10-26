import 'dart:convert';

import 'payment_templates.dart';

/// Сколько шаблонов пользователя хранится: больше не нужно, и список остаётся
/// обозримым.
const maxUserTemplates = 50;

/// Название в списке шаблонов не длиннее названия платежа.
const _maxNameLength = 80;

/// Сколько хранить и в каком виде сравнивать названия: «Интернет» и
/// «интернет » — один и тот же шаблон.
String _key(String name) => name.toLowerCase().replaceAll('ё', 'е').trim();

/// Добавляет шаблон [t] в список [current]: шаблон с таким же названием
/// заменяется (и встаёт первым), новые добавляются в начало. Лишние старые
/// отбрасываются сверх [maxUserTemplates].
List<PaymentTemplate> withTemplate(
  List<PaymentTemplate> current,
  PaymentTemplate t,
) {
  final key = _key(t.name);
  final result = [
    t,
    for (final old in current)
      if (_key(old.name) != key) old,
  ];
  return result.length > maxUserTemplates
      ? result.sublist(0, maxUserTemplates)
      : result;
}

/// Убирает шаблон с названием [name].
List<PaymentTemplate> withoutTemplate(
  List<PaymentTemplate> current,
  String name,
) {
  final key = _key(name);
  return [
    for (final t in current)
      if (_key(t.name) != key) t,
  ];
}

/// Список шаблонов в текст для хранения на устройстве.
String encodeUserTemplates(List<PaymentTemplate> templates) {
  return jsonEncode([
    for (final t in templates)
      {
        'name': t.name,
        'category': t.categoryName,
        'period': t.periodMonths,
        'variable': t.variableAmount,
        'amount': t.amountKopecks,
        'remind': t.remindDaysBefore,
        'day': t.dayOfMonth,
      },
  ]);
}

/// Читает сохранённые шаблоны. Испорченная запись пропускается, а не ломает
/// весь список; пустой или непонятный текст даёт пустой список.
List<PaymentTemplate> decodeUserTemplates(String? text) {
  if (text == null || text.isEmpty) return const [];
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException {
    return const [];
  }
  if (root is! List) return const [];

  final result = <PaymentTemplate>[];
  for (final entry in root) {
    if (entry is! Map) continue;
    final name = entry['name'];
    final category = entry['category'];
    final period = entry['period'];
    final variable = entry['variable'];
    final amount = entry['amount'];
    final remind = entry['remind'];
    final day = entry['day'];
    if (name is! String || name.trim().isEmpty) continue;
    if (name.length > _maxNameLength) continue;
    if (category is! String) continue;
    if (period is! int || period < 1) continue;
    if (variable is! bool) continue;
    if (amount != null && (amount is! int || amount < 0)) continue;
    if (remind is! int || remind < 0) continue;
    if (day != null && (day is! int || day < 1 || day > 31)) continue;
    result.add(
      PaymentTemplate(
        name,
        category,
        periodMonths: period,
        variableAmount: variable,
        amountKopecks: amount as int?,
        remindDaysBefore: remind,
        dayOfMonth: day as int?,
      ),
    );
    if (result.length >= maxUserTemplates) break;
  }
  return result;
}
