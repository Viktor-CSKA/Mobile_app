import 'dart:convert';

import 'package:ezhemesyachno/features/backup/domain/backup_codec.dart';
import 'package:ezhemesyachno/features/backup/domain/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/backup_samples.dart';

List<String> lines(String csv) => csv.split('\r\n');

void main() {
  group('csvField', () {
    test('обычный текст без изменений', () {
      expect(csvField('Интернет'), 'Интернет');
      expect(csvField(''), '');
    });

    test('точка с запятой берётся в кавычки', () {
      expect(csvField('a;b'), '"a;b"');
    });

    test('кавычки удваиваются', () {
      expect(csvField('say "hi"'), '"say ""hi"""');
    });

    test('перенос строки берётся в кавычки', () {
      expect(csvField('a\nb'), '"a\nb"');
      expect(csvField('a\rb'), '"a\rb"');
    });

    test('запятая и пробелы не требуют кавычек', () {
      expect(csvField('1,5 и 2'), '1,5 и 2');
    });

    test('защита от формул Excel: впереди апостроф', () {
      expect(csvField('=SUM(A1)'), "'=SUM(A1)");
      expect(csvField('+7 999'), "'+7 999");
      expect(csvField('-5'), "'-5");
      expect(csvField('@cmd'), "'@cmd");
    });

    test('защита от формул и кавычки вместе', () {
      expect(csvField('=1;2'), "\"'=1;2\"");
    });

    test('знак в середине не трогается', () {
      expect(csvField('a=b'), 'a=b');
    });
  });

  group('csvAmount', () {
    test('рубли и копейки', () {
      expect(csvAmount(69000), '690,00');
      expect(csvAmount(123456), '1234,56');
      expect(csvAmount(5), '0,05');
      expect(csvAmount(0), '0,00');
      expect(csvAmount(1200000), '12000,00');
    });
  });

  group('csvBytes', () {
    test('начинается с BOM и содержит UTF-8', () {
      final b = csvBytes('Привет');
      expect(b.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(b.sublist(3)), 'Привет');
    });
  });

  group('таблица платежей', () {
    final rows = lines(paymentsCsv(sampleData()));

    test('заголовок и число строк', () {
      expect(
        rows.first,
        'Название;Категория;Сумма, ₽;Сумма меняется;Периодичность;'
        'Ближайший платёж;Дата окончания;Напоминать за, дн.;Заметка;Статус',
      );
      expect(rows.length, 1 + 4);
    });

    test('платёж с фиксированной суммой и спецсимволами в заметке', () {
      // Заметка с точкой с запятой, кавычками и переносом строки в кавычках.
      final text = paymentsCsv(sampleData());
      expect(
        text,
        contains(
          'Интернет;Подписки;690,00;нет;Каждый месяц;20.10.2026;;1;'
          '"Дом; ""основной""\nвторая строка";Активен',
        ),
      );
    });

    test('переменная сумма: пусто и «да»', () {
      expect(
        rows[2],
        'Электричество;ЖКХ;;да;Каждый месяц;10.10.2026;;3;;Активен',
      );
    });

    test('кредит с датой окончания', () {
      expect(
        rows[3],
        'Кредит;ЖКХ;12000,00;нет;Каждый месяц;25.10.2026;25.03.2027;1;;Активен',
      );
    });

    test('закрытый платёж помечен «Завершён», период раз в квартал', () {
      expect(
        rows[4],
        'Рассрочка;Подписки;5000,00;нет;Раз в квартал;10.08.2026;10.08.2026;7;выплачена;Завершён',
      );
    });

    test('пустой список даёт только заголовок', () {
      const empty = BackupData(categories: [], payments: [], records: []);
      expect(lines(paymentsCsv(empty)).length, 1);
    });

    test('название с формулой защищено', () {
      final data = sampleData();
      final evil = BackupData(
        categories: data.categories,
        payments: [
          data.payments.first.copyWith(name: '=HYPERLINK("http://x")'),
        ],
        records: const [],
      );
      expect(paymentsCsv(evil), contains('"\'=HYPERLINK(""http://x"")"'));
    });
  });

  group('таблица истории оплат', () {
    final rows = lines(historyCsv(sampleData()));

    test('заголовок', () {
      expect(rows.first, 'Дата оплаты;Платёж;Категория;Сумма, ₽');
    });

    test('сначала более ранние оплаты', () {
      expect(rows.length, 3);
      expect(rows[1], '10.08.2026 09:00;Рассрочка;Подписки;5000,00');
      expect(rows[2], '20.09.2026 18:30;Интернет;Подписки;690,00');
    });

    test('время с ведущими нулями', () {
      final data = sampleData();
      final custom = BackupData(
        categories: data.categories,
        payments: data.payments,
        records: [
          data.records.first.copyWith(paidAt: DateTime(2026, 1, 5, 7, 3)),
        ],
      );
      expect(lines(historyCsv(custom))[1], startsWith('05.01.2026 07:03;'));
    });

    test('оплата неизвестного платежа не ломает таблицу', () {
      final data = sampleData();
      final odd = BackupData(
        categories: data.categories,
        payments: const [],
        records: data.records,
      );
      expect(lines(historyCsv(odd)).length, 3);
    });

    test('пустая история', () {
      const empty = BackupData(categories: [], payments: [], records: []);
      expect(lines(historyCsv(empty)).length, 1);
    });
  });
}
