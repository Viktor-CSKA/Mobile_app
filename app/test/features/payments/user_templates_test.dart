import 'dart:convert';

import 'package:ezhemesyachno/features/payments/domain/payment_templates.dart';
import 'package:ezhemesyachno/features/payments/domain/user_templates.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentTemplate t(String name, {int? amount = 10000, int period = 1}) =>
    PaymentTemplate(
      name,
      'Прочее',
      periodMonths: period,
      amountKopecks: amount,
      dayOfMonth: 15,
    );

void main() {
  group('список шаблонов', () {
    test('новый шаблон встаёт первым', () {
      final list = withTemplate([t('А'), t('Б')], t('В'));
      expect(list.map((e) => e.name), ['В', 'А', 'Б']);
    });

    test('шаблон с тем же названием заменяется и встаёт первым', () {
      final list = withTemplate([
        t('А'),
        t('Б', amount: 100),
      ], t('б', amount: 5));
      expect(list.map((e) => e.name), ['б', 'А']);
      expect(list.first.amountKopecks, 5);
    });

    test('«ё» и «е», регистр и пробелы — одно и то же название', () {
      final list = withTemplate([t('Счётчик')], t(' СЧЕТЧИК '));
      expect(list, hasLength(1));
    });

    test('сверх предела старые отбрасываются', () {
      var list = <PaymentTemplate>[];
      for (var i = 0; i < maxUserTemplates + 5; i++) {
        list = withTemplate(list, t('Шаблон $i'));
      }
      expect(list, hasLength(maxUserTemplates));
      expect(list.first.name, 'Шаблон ${maxUserTemplates + 4}');
    });

    test('удаление по названию', () {
      final list = withoutTemplate([t('А'), t('Б')], 'а');
      expect(list.map((e) => e.name), ['Б']);
      expect(withoutTemplate([t('А')], 'нет'), hasLength(1));
    });
  });

  group('хранение', () {
    test('круг: записали и прочитали те же шаблоны', () {
      final src = [
        PaymentTemplate(
          'Спортзал',
          'Подписки',
          periodMonths: 3,
          amountKopecks: 250000,
          remindDaysBefore: 7,
          dayOfMonth: 5,
        ),
        PaymentTemplate(
          'Свет',
          'ЖКХ',
          variableAmount: true,
          remindDaysBefore: 3,
          dayOfMonth: 10,
        ),
      ];
      final back = decodeUserTemplates(encodeUserTemplates(src));

      expect(back, hasLength(2));
      expect(back[0].name, 'Спортзал');
      expect(back[0].categoryName, 'Подписки');
      expect(back[0].periodMonths, 3);
      expect(back[0].amountKopecks, 250000);
      expect(back[0].remindDaysBefore, 7);
      expect(back[0].dayOfMonth, 5);
      expect(back[1].variableAmount, isTrue);
      expect(back[1].amountKopecks, isNull);
    });

    test('пусто, мусор и не тот тип — пустой список', () {
      expect(decodeUserTemplates(null), isEmpty);
      expect(decodeUserTemplates(''), isEmpty);
      expect(decodeUserTemplates('не json'), isEmpty);
      expect(decodeUserTemplates('{"a": 1}'), isEmpty);
    });

    test('битая запись пропускается, остальные читаются', () {
      Map<String, Object?> ok(String name) => {
        'name': name,
        'category': 'Прочее',
        'period': 1,
        'variable': false,
        'amount': 100,
        'remind': 1,
        'day': 5,
      };
      final text = jsonEncode([
        ok('Первый'),
        {...ok('Без периода'), 'period': 0},
        {...ok('Дробная сумма'), 'amount': 1.5},
        {...ok('День 40'), 'day': 40},
        {...ok(''), 'name': ''},
        'просто строка',
        ok('Последний'),
      ]);
      expect(decodeUserTemplates(text).map((e) => e.name), [
        'Первый',
        'Последний',
      ]);
    });

    test('поиск среди своих шаблонов', () {
      final mine = [t('Спортзал'), t('Школа')];
      expect(searchIn(mine, 'спорт').map((e) => e.name), ['Спортзал']);
      expect(searchIn(mine, '').map((e) => e.name), ['Спортзал', 'Школа']);
    });
  });
}
