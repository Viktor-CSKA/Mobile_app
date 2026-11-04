import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:ezhemesyachno/features/widget/domain/widget_data.dart';
import 'package:flutter_test/flutter_test.dart';

const _category = Category(id: 1, name: 'Подписки', colorValue: 0xFF8E24AA);

/// Неразрывный пробел, которым `formatKopecks` отделяет рубли от «₽».
const _nbsp = '\u00A0';

PaymentWithCategory pay(
  String name,
  DateTime due, {
  int? amount = 10000,
  int period = 1,
  DateTime? ends,
  bool active = true,
}) => PaymentWithCategory(
  Payment(
    id: name.hashCode,
    name: name,
    categoryId: 1,
    amountKopecks: amount,
    periodMonths: period,
    nextDueAt: due,
    anchorDay: due.day,
    remindDaysBefore: 1,
    endsAt: ends,
    note: '',
    isActive: active,
  ),
  _category,
);

void main() {
  final today = DateTime(2026, 10, 15, 14, 30);

  group('пустое состояние', () {
    test('нет платежей — подсказка, ноль платежей', () {
      final d = WidgetData.build(const [], today);
      expect(d.isEmpty, isTrue);
      expect(d.monthTotalLabel, '0$_nbsp₽');
      expect(d.noteLabel, '0 платежей');
      expect(d.payments, isEmpty);
      expect(d.overdueCount, 0);
    });

    test('неактивные платежи не считаются', () {
      final d = WidgetData.build([
        pay('Закрыт', DateTime(2026, 10, 20), active: false),
      ], today);
      expect(d.isEmpty, isTrue);
    });
  });

  group('итог месяца и примечание', () {
    test('фиксированные, переменная сумма и просрочка', () {
      final d = WidgetData.build([
        pay('Кредит', DateTime(2026, 10, 1), amount: 50000),
        pay('Подписка', DateTime(2026, 10, 20), amount: 19900),
        pay('ЖКХ', DateTime(2026, 10, 25), amount: null),
      ], today);
      expect(d.monthTotalLabel, '699$_nbsp₽');
      expect(d.noteLabel, '3 платежа · 1 с переменной суммой · 1 просрочен');
      expect(d.overdueCount, 1);
      expect(d.isEmpty, isFalse);
    });

    test('без просрочки и переменных сумм примечание короткое', () {
      final d = WidgetData.build([
        pay('Подписка', DateTime(2026, 10, 20), amount: 19900),
        pay('Связь', DateTime(2026, 10, 22), amount: 30000),
      ], today);
      expect(d.noteLabel, '2 платежа');
      expect(d.overdueCount, 0);
    });

    test('склонение «платежей» при большом числе', () {
      final d = WidgetData.build([
        pay('П1', DateTime(2026, 10, 16)),
        pay('П2', DateTime(2026, 10, 17)),
        pay('П3', DateTime(2026, 10, 18)),
        pay('П4', DateTime(2026, 10, 19)),
        pay('П5', DateTime(2026, 10, 20)),
        pay('П6', DateTime(2026, 10, 21)),
      ], today);
      expect(d.noteLabel, '6 платежей');
    });
  });

  group('ближайшие платежи', () {
    test('просроченные первыми, потом по дате, не больше трёх', () {
      final d = WidgetData.build([
        pay('Давний', DateTime(2026, 10, 1)),
        pay('Скоро', DateTime(2026, 10, 17)),
        pay('Потом', DateTime(2026, 10, 20)),
        pay('Ещё позже', DateTime(2026, 10, 25)),
      ], today);
      expect(d.payments.map((e) => e.name), ['Давний', 'Скоро', 'Потом']);
    });

    test('подписи дат и суммы', () {
      final d = WidgetData.build([
        pay('Кредит', DateTime(2026, 10, 1), amount: 50000),
        pay('ЖКХ', DateTime(2026, 10, 25), amount: null),
      ], today);
      final credit = d.payments[0];
      expect(credit.name, 'Кредит');
      expect(credit.dueLabel, 'просрочено на 14 дн.');
      expect(credit.amountLabel, '500$_nbsp₽');
      expect(credit.colorHex, '#8e24aa');

      final housing = d.payments[1];
      expect(housing.name, 'ЖКХ');
      expect(housing.dueLabel, 'через 10 дн.');
      expect(housing.amountLabel, isNull);
    });

    test('завтра и сегодня', () {
      final d = WidgetData.build([
        pay('Сегодня', DateTime(2026, 10, 15)),
        pay('Завтра', DateTime(2026, 10, 16)),
      ], today);
      expect(d.payments[0].dueLabel, 'сегодня');
      expect(d.payments[1].dueLabel, 'завтра');
    });
  });

  group('сериализация', () {
    test('JSON-раундтрип сохраняет данные', () {
      final d = WidgetData.build([
        pay('Кредит', DateTime(2026, 10, 1), amount: 50000),
        pay('ЖКХ', DateTime(2026, 10, 25), amount: null),
      ], today);
      final restored = WidgetData.fromJson(d.toJson());
      expect(restored.monthTotalLabel, d.monthTotalLabel);
      expect(restored.noteLabel, d.noteLabel);
      expect(restored.overdueCount, d.overdueCount);
      expect(restored.isEmpty, d.isEmpty);
      expect(restored.payments.length, d.payments.length);
      for (var i = 0; i < d.payments.length; i++) {
        expect(restored.payments[i].name, d.payments[i].name);
        expect(restored.payments[i].amountLabel, d.payments[i].amountLabel);
        expect(restored.payments[i].dueLabel, d.payments[i].dueLabel);
        expect(restored.payments[i].colorHex, d.payments[i].colorHex);
      }
    });
  });

  group('colorToHex', () {
    test('без альфа-канала, в нижнем регистре', () {
      expect(colorToHex(0xFF8E24AA), '#8e24aa');
      expect(colorToHex(0xFF000000), '#000000');
      expect(colorToHex(0xFFFFFFFF), '#ffffff');
    });
  });
}
