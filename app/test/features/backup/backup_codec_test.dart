import 'dart:convert';

import 'package:ezhemesyachno/features/backup/domain/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/backup_samples.dart';

Map<String, Object?> encoded() => jsonDecode(
  encodeBackup(sampleData(), exportedAt: DateTime.utc(2026, 10, 15, 9)),
) as Map<String, Object?>;

/// Разбирает изменённый JSON и возвращает текст ошибки формата.
String errorOf(void Function(Map<String, Object?> json) edit) {
  final json = encoded();
  edit(json);
  try {
    decodeBackup(jsonEncode(json));
  } on BackupFormatException catch (e) {
    return e.message;
  }
  fail('Ожидалась ошибка формата');
}

Map<String, Object?> payment0(Map<String, Object?> json) =>
    ((json['payments'] as List<Object?>)[0]) as Map<String, Object?>;

void main() {
  group('кодирование', () {
    test('заголовок файла', () {
      final j = encoded();
      expect(j['app'], 'ezhemesyachno');
      expect(j['formatVersion'], 1);
      expect(j['exportedAt'], '2026-10-15T09:00:00.000Z');
    });

    test('даты платежей без времени, оплаты в UTC', () {
      final j = encoded();
      expect(payment0(j)['nextDueAt'], '2026-10-20');
      expect(payment0(j)['endsAt'], isNull);
      final records = j['records'] as List<Object?>;
      expect((records[0] as Map)['paidAt'], endsWith('Z'));
    });

    test('переменная сумма записывается как null', () {
      final j = encoded();
      expect(((j['payments'] as List)[1] as Map)['amountKopecks'], isNull);
    });

    test('пустые данные кодируются и читаются', () {
      const empty = BackupData(categories: [], payments: [], records: []);
      final back = decodeBackup(
        encodeBackup(empty, exportedAt: DateTime.utc(2026)),
      );
      expect(back.payments, isEmpty);
      expect(back.categories, isEmpty);
      expect(back.records, isEmpty);
    });
  });

  group('круговой обмен', () {
    test('данные после записи и чтения совпадают полностью', () {
      final text = encodeBackup(
        sampleData(),
        exportedAt: DateTime.utc(2026, 10, 15),
      );
      expectSameData(decodeBackup(text), sampleData());
    });

    test(
      'кириллица, кавычки, точка с запятой и перенос строки сохраняются',
      () {
        final back = decodeBackup(
          encodeBackup(sampleData(), exportedAt: DateTime.utc(2026, 10, 15)),
        );
        expect(back.payments.first.note, 'Дом; "основной"\nвторая строка');
      },
    );

    test('лишние неизвестные поля игнорируются', () {
      final json = encoded()..['future'] = {'x': 1};
      payment0(json)['extra'] = 'ignored';
      expectSameData(decodeBackup(jsonEncode(json)), sampleData());
    });

    test('отсутствующая заметка читается как пустая', () {
      final json = encoded();
      payment0(json).remove('note');
      expect(decodeBackup(jsonEncode(json)).payments.first.note, '');
    });
  });

  group('отказ: это не наша копия', () {
    const notOurs = 'Это не файл резервной копии «Ежемесячно»';

    test('не JSON', () {
      expect(
        () => decodeBackup('привет'),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            notOurs,
          ),
        ),
      );
    });

    test('пустой текст', () {
      expect(() => decodeBackup(''), throwsA(isA<BackupFormatException>()));
    });

    test('JSON не объект', () {
      expect(
        () => decodeBackup('[1,2,3]'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => decodeBackup('"text"'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(() => decodeBackup('null'), throwsA(isA<BackupFormatException>()));
    });

    test('чужое приложение', () {
      expect(errorOf((j) => j['app'] = 'other'), notOurs);
    });

    test('нет идентификатора приложения', () {
      expect(errorOf((j) => j.remove('app')), notOurs);
    });
  });

  group('отказ: версия формата', () {
    test('более новая версия', () {
      expect(
        errorOf((j) => j['formatVersion'] = 2),
        contains('более новой версией'),
      );
    });

    test('нет версии', () {
      expect(errorOf((j) => j.remove('formatVersion')), contains('версию'));
    });

    test('версия не число или меньше 1', () {
      expect(errorOf((j) => j['formatVersion'] = '1'), contains('версию'));
      expect(errorOf((j) => j['formatVersion'] = 0), contains('версию'));
    });
  });

  group('отказ: структура', () {
    test('нет раздела платежей', () {
      expect(errorOf((j) => j.remove('payments')), contains('«payments»'));
    });

    test('раздел не список', () {
      expect(errorOf((j) => j['records'] = {}), contains('«records»'));
    });

    test('запись не объект', () {
      expect(
        errorOf((j) => (j['categories'] as List).add(5)),
        contains('Категория №3'),
      );
    });

    test('дубль номера категории', () {
      expect(
        errorOf((j) => ((j['categories'] as List)[1] as Map)['id'] = 1),
        contains('повторяющийся номер'),
      );
    });

    test('дубль номера платежа', () {
      expect(
        errorOf((j) => ((j['payments'] as List)[1] as Map)['id'] = 1),
        contains('Платёж №2: повторяющийся номер'),
      );
    });

    test('слишком много записей', () {
      expect(
        errorOf((j) => j['records'] = List.filled(100001, <String, Object?>{})),
        contains('Слишком много'),
      );
    });
  });

  group('отказ: значения', () {
    test('неизвестная категория у платежа', () {
      expect(
        errorOf((j) => payment0(j)['categoryId'] = 99),
        'Платёж №1: неизвестная категория',
      );
    });

    test('неизвестный платёж у оплаты', () {
      expect(
        errorOf((j) => ((j['records'] as List)[0] as Map)['paymentId'] = 77),
        'Оплата №1: неизвестный платёж',
      );
    });

    test('пустое название', () {
      expect(errorOf((j) => payment0(j)['name'] = '   '), contains('название'));
    });

    test('слишком длинное название', () {
      expect(
        errorOf((j) => payment0(j)['name'] = 'я' * 81),
        contains('название'),
      );
    });

    test('отрицательная сумма', () {
      expect(
        errorOf((j) => payment0(j)['amountKopecks'] = -1),
        contains('сумма'),
      );
    });

    test('сумма не число', () {
      expect(
        errorOf((j) => payment0(j)['amountKopecks'] = '690'),
        contains('сумма'),
      );
    });

    test('период вне диапазона', () {
      expect(
        errorOf((j) => payment0(j)['periodMonths'] = 0),
        contains('период'),
      );
      expect(
        errorOf((j) => payment0(j)['periodMonths'] = 121),
        contains('период'),
      );
    });

    test('день месяца вне диапазона', () {
      expect(
        errorOf((j) => payment0(j)['anchorDay'] = 0),
        contains('день месяца'),
      );
      expect(
        errorOf((j) => payment0(j)['anchorDay'] = 32),
        contains('день месяца'),
      );
    });

    test('напоминание вне диапазона', () {
      expect(
        errorOf((j) => payment0(j)['remindDaysBefore'] = -1),
        contains('напоминание'),
      );
      expect(
        errorOf((j) => payment0(j)['remindDaysBefore'] = 366),
        contains('напоминание'),
      );
    });

    test('несуществующая дата (30 февраля)', () {
      expect(
        errorOf((j) => payment0(j)['nextDueAt'] = '2026-02-30'),
        contains('дата платежа'),
      );
    });

    test('дата в неверном формате', () {
      for (final bad in ['20.10.2026', '2026-1-5', '', 20261020]) {
        expect(
          errorOf((j) => payment0(j)['nextDueAt'] = bad),
          contains('дата платежа'),
        );
      }
    });

    test('некорректная дата окончания', () {
      expect(
        errorOf((j) => payment0(j)['endsAt'] = 'завтра'),
        contains('дата окончания'),
      );
    });

    test('не указан признак активности', () {
      expect(
        errorOf((j) => payment0(j).remove('isActive')),
        contains('активен'),
      );
      expect(
        errorOf((j) => payment0(j)['isActive'] = 'yes'),
        contains('активен'),
      );
    });

    test('слишком длинная заметка', () {
      expect(
        errorOf((j) => payment0(j)['note'] = 'x' * 2001),
        contains('заметка'),
      );
    });

    test('некорректный цвет категории', () {
      expect(
        errorOf(
          (j) => ((j['categories'] as List)[0] as Map)['colorValue'] = -5,
        ),
        contains('цвет'),
      );
    });

    test('некорректная дата оплаты', () {
      expect(
        errorOf((j) => ((j['records'] as List)[0] as Map)['paidAt'] = 'вчера'),
        contains('дата оплаты'),
      );
    });

    test('отрицательная сумма оплаты', () {
      expect(
        errorOf(
          (j) => ((j['records'] as List)[0] as Map)['amountKopecks'] = -10,
        ),
        contains('сумма'),
      );
    });

    test('слишком большой файл', () {
      expect(
        () => decodeBackup('x' * (50 * 1000 * 1000 + 1)),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
