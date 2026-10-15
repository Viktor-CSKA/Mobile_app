import 'package:drift/native.dart';
import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_schedule.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_templates.dart';
import 'package:ezhemesyachno/features/payments/presentation/payment_labels.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentTemplate byName(String name) =>
    paymentTemplates.firstWhere((t) => t.name == name);

void main() {
  group('каталог', () {
    test('названия уникальны без учёта регистра', () {
      final names = paymentTemplates.map((t) => t.name.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
    });

    test('периоды и сроки напоминания есть в выпадающих списках формы', () {
      for (final t in paymentTemplates) {
        expect(
          periodOptions.containsKey(t.periodMonths),
          isTrue,
          reason: t.name,
        );
        expect(
          remindOptions.containsKey(t.remindDaysBefore),
          isTrue,
          reason: t.name,
        );
      }
    });

    test(
      'категории шаблонов совпадают со стандартными категориями приложения',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final names = (await db.select(db.categories).get())
            .map((c) => c.name)
            .toSet();
        for (final t in paymentTemplates) {
          expect(names, contains(t.categoryName), reason: t.name);
        }
        // и каждая стандартная категория представлена хотя бы одним шаблоном
        final used = paymentTemplates.map((t) => t.categoryName).toSet();
        expect(used, names);
      },
    );

    test(
      'шаблоны одной категории идут подряд (список в окне строится по группам)',
      () {
        final seen = <String>{};
        String? current;
        for (final t in paymentTemplates) {
          if (t.categoryName != current) {
            expect(
              seen.add(t.categoryName),
              isTrue,
              reason: 'группа повторяется: ${t.categoryName}',
            );
            current = t.categoryName;
          }
        }
      },
    );

    test('сроки заданы корректно', () {
      for (final t in paymentTemplates) {
        if (t.dayOfMonth != null) {
          expect(t.dayOfMonth, inInclusiveRange(1, 31), reason: t.name);
        }
        if (t.yearlyMonth != null || t.yearlyDay != null) {
          expect(t.yearlyMonth, isNotNull, reason: t.name);
          expect(t.yearlyDay, isNotNull, reason: t.name);
          expect(t.yearlyMonth, inInclusiveRange(1, 12), reason: t.name);
          expect(
            t.yearlyDay,
            inInclusiveRange(1, daysInMonth(2028, t.yearlyMonth!)),
            reason: t.name,
          );
          expect(
            t.periodMonths,
            12,
            reason: '${t.name}: ежегодный срок — раз в год',
          );
          expect(t.dayOfMonth, isNull, reason: t.name);
        }
      }
    });

    test('быстрый выбор: 6–10 шаблонов', () {
      expect(popularTemplates.length, inInclusiveRange(6, 10));
    });

    test('коммунальные услуги с переменной суммой, подписки — без', () {
      expect(byName('Электричество').variableAmount, isTrue);
      expect(byName('Квартплата (ЖКУ)').variableAmount, isTrue);
      expect(byName('Яндекс Плюс').variableAmount, isFalse);
      expect(byName('Кредит').variableAmount, isFalse);
    });

    test('налоги и страховки — раз в год с напоминанием за неделю', () {
      for (final n in [
        'Налог на имущество',
        'Транспортный налог',
        'ОСАГО',
        'КАСКО',
      ]) {
        final t = byName(n);
        expect(t.periodMonths, 12, reason: n);
        expect(t.remindDaysBefore, 7, reason: n);
      }
    });
  });

  group('suggestedDue', () {
    test('налог: ближайшее 1 декабря в этом году', () {
      expect(
        suggestedDue(byName('Налог на имущество'), DateTime(2026, 10, 15)),
        DateTime(2026, 12, 1),
      );
    });

    test('налог: 1 декабря уже прошло — следующий год', () {
      expect(
        suggestedDue(byName('Налог на имущество'), DateTime(2026, 12, 2)),
        DateTime(2027, 12, 1),
      );
    });

    test('налог: ровно 1 декабря — сегодня', () {
      expect(
        suggestedDue(byName('Налог на имущество'), DateTime(2026, 12, 1, 18)),
        DateTime(2026, 12, 1),
      );
    });

    test('ЖКУ: 10-е число этого месяца, если не прошло', () {
      expect(
        suggestedDue(byName('Электричество'), DateTime(2026, 10, 5)),
        DateTime(2026, 10, 10),
      );
      expect(
        suggestedDue(byName('Электричество'), DateTime(2026, 10, 10)),
        DateTime(2026, 10, 10),
      );
    });

    test('ЖКУ: 10-е прошло — следующий месяц, в том числе через год', () {
      expect(
        suggestedDue(byName('Электричество'), DateTime(2026, 10, 11)),
        DateTime(2026, 11, 10),
      );
      expect(
        suggestedDue(byName('Электричество'), DateTime(2026, 12, 20)),
        DateTime(2027, 1, 10),
      );
    });

    test('без привычного срока — null', () {
      expect(
        suggestedDue(byName('Яндекс Плюс'), DateTime(2026, 10, 15)),
        isNull,
      );
      expect(suggestedDue(byName('Кредит'), DateTime(2026, 10, 15)), isNull);
    });

    test('день 31 прижимается к концу короткого месяца', () {
      const t = PaymentTemplate('Тест', 'Прочее', dayOfMonth: 31);
      expect(suggestedDue(t, DateTime(2026, 2, 5)), DateTime(2026, 2, 28));
      expect(suggestedDue(t, DateTime(2026, 2, 28)), DateTime(2026, 2, 28));
      expect(suggestedDue(t, DateTime(2026, 4, 30, 23)), DateTime(2026, 4, 30));
    });
  });

  group('categoryIdFor', () {
    const cats = [(id: 1, name: 'ЖКХ'), (id: 4, name: 'Подписки')];

    test('находит по названию', () {
      expect(categoryIdFor(byName('Электричество'), cats), 1);
      expect(categoryIdFor(byName('Кинопоиск'), cats), 4);
    });

    test('нет такой категории — null', () {
      expect(categoryIdFor(byName('Кредит'), cats), isNull);
      expect(categoryIdFor(byName('Кредит'), const []), isNull);
    });
  });

  group('searchTemplates', () {
    test('пустой запрос — весь каталог', () {
      expect(searchTemplates('').length, paymentTemplates.length);
      expect(searchTemplates('   ').length, paymentTemplates.length);
    });

    test('по части названия без учёта регистра', () {
      expect(searchTemplates('ипот').map((t) => t.name), contains('Ипотека'));
      expect(searchTemplates('ИПОТ').map((t) => t.name), contains('Ипотека'));
    });

    test('слово из середины названия находится', () {
      expect(
        searchTemplates('квартплата').map((t) => t.name),
        contains('Квартплата (ЖКУ)'),
      );
      expect(
        searchTemplates('жку').map((t) => t.name),
        contains('Квартплата (ЖКУ)'),
      );
    });

    test('по названию категории', () {
      final found = searchTemplates('страховка');
      expect(found, isNotEmpty);
      expect(found.every((t) => t.categoryName == 'Страховка'), isTrue);
    });

    test('ничего не найдено', () {
      expect(searchTemplates('зззз'), isEmpty);
    });

    test('порядок каталога сохраняется', () {
      final found = searchTemplates('налог').map((t) => t.name).toList();
      expect(found, [
        'Налог на имущество',
        'Транспортный налог',
        'Земельный налог',
      ]);
    });
  });
}
