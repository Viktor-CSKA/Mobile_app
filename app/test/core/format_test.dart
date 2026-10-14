import 'package:ezhemesyachno/core/format/date_format_ru.dart';
import 'package:ezhemesyachno/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatKopecks', () {
    test('целые рубли без копеек', () {
      expect(formatKopecks(120000), '1 200 ₽');
    });
    test('копейки', () {
      expect(formatKopecks(123456), '1 234,56 ₽');
    });
    test('копейки с ведущим нулём', () {
      expect(formatKopecks(10005), '100,05 ₽');
    });
    test('ноль', () {
      expect(formatKopecks(0), '0 ₽');
    });
    test('миллионы', () {
      expect(formatKopecks(123456789000), '1 234 567 890 ₽');
    });
    test('отрицательная сумма', () {
      expect(formatKopecks(-5000), '−50 ₽');
    });
  });

  group('parseRubles', () {
    test('целое число', () => expect(parseRubles('599'), 59900));
    test('запятая', () => expect(parseRubles('1234,56'), 123456));
    test('точка', () => expect(parseRubles('1234.5'), 123450));
    test(
      'пробелы-разделители',
      () => expect(parseRubles('1 234 567'), 123456700),
    );
    test('неразрывный пробел', () => expect(parseRubles('1 200'), 120000));
    test('ноль', () => expect(parseRubles('0'), 0));
    test('пустая строка', () => expect(parseRubles('  '), isNull));
    test('буквы', () => expect(parseRubles('abc'), isNull));
    test('отрицательное', () => expect(parseRubles('-5'), isNull));
    test('три знака после запятой', () => expect(parseRubles('1,234'), isNull));
    test('две запятые', () => expect(parseRubles('1,2,3'), isNull));
  });

  group('даты', () {
    test('короткий формат', () {
      expect(formatDayMonthShort(DateTime(2026, 10, 5)), '5 окт');
      expect(formatDayMonthShort(DateTime(2026, 5, 31)), '31 мая');
    });
    test('полный формат', () {
      expect(formatDateFull(DateTime(2026, 3, 8)), '8 марта 2026');
    });
  });
}
