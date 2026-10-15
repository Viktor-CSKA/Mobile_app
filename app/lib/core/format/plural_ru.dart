/// Склонение по числу: `pluralRu(1, 'платёж', 'платежа', 'платежей')` → `платёж`.
String pluralRu(int n, String one, String few, String many) {
  final mod100 = n.abs() % 100;
  final mod10 = n.abs() % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

/// `3` → `3 платежа`.
String paymentsCountLabel(int n) =>
    '$n ${pluralRu(n, 'платёж', 'платежа', 'платежей')}';
