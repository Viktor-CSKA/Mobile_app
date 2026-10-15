import 'package:ezhemesyachno/core/format/plural_ru.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String p(int n) => pluralRu(n, 'платёж', 'платежа', 'платежей');

  test('один', () {
    expect(p(1), 'платёж');
    expect(p(21), 'платёж');
    expect(p(101), 'платёж');
  });

  test('два–четыре', () {
    expect(p(2), 'платежа');
    expect(p(3), 'платежа');
    expect(p(4), 'платежа');
    expect(p(22), 'платежа');
  });

  test('много и ноль', () {
    expect(p(0), 'платежей');
    expect(p(5), 'платежей');
    expect(p(20), 'платежей');
    expect(p(100), 'платежей');
  });

  test('11–14 всегда «платежей»', () {
    for (final n in [11, 12, 13, 14, 111, 112]) {
      expect(p(n), 'платежей', reason: '$n');
    }
  });

  test('подпись с числом', () {
    expect(paymentsCountLabel(1), '1 платёж');
    expect(paymentsCountLabel(3), '3 платежа');
    expect(paymentsCountLabel(12), '12 платежей');
  });
}
