/// Форматирует копейки как рубли: `123456` → `1 234,56 ₽`, `120000` → `1 200 ₽`.
String formatKopecks(int kopecks) {
  final negative = kopecks < 0;
  final abs = kopecks.abs();
  final rubles = abs ~/ 100;
  final cents = abs % 100;
  final digits = rubles.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  final sign = negative ? '−' : '';
  final tail = cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}';
  return '$sign$buffer$tail ₽';
}

/// Разбирает введённую сумму в рублях в копейки: `1 234,5` → `123450`.
///
/// Возвращает null для пустой строки и для всего, что не является суммой
/// (буквы, отрицательные числа, больше двух знаков после запятой).
int? parseRubles(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s  ]'), '');
  if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(cleaned)) return null;
  final parts = cleaned.split(RegExp(r'[.,]'));
  final rubles = int.tryParse(parts[0]);
  if (rubles == null) return null;
  final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return rubles * 100 + cents;
}
