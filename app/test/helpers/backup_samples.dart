import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/backup/domain/backup_codec.dart';

const kHousing = Category(id: 1, name: 'ЖКХ', colorValue: 0xFF795548);
const kSubs = Category(id: 2, name: 'Подписки', colorValue: 0xFF8E24AA);

/// Набор данных на все случаи: фиксированная и переменная сумма, кредит с
/// датой окончания, закрытая рассрочка, спецсимволы в тексте, две оплаты.
BackupData sampleData() => BackupData(
  categories: const [kHousing, kSubs],
  payments: [
    Payment(
      id: 1,
      name: 'Интернет',
      categoryId: 2,
      amountKopecks: 69000,
      periodMonths: 1,
      nextDueAt: DateTime(2026, 10, 20),
      anchorDay: 20,
      remindDaysBefore: 1,
      endsAt: null,
      note: 'Дом; "основной"\nвторая строка',
      isActive: true,
    ),
    Payment(
      id: 2,
      name: 'Электричество',
      categoryId: 1,
      amountKopecks: null,
      periodMonths: 1,
      nextDueAt: DateTime(2026, 10, 10),
      anchorDay: 10,
      remindDaysBefore: 3,
      endsAt: null,
      note: '',
      isActive: true,
    ),
    Payment(
      id: 3,
      name: 'Кредит',
      categoryId: 1,
      amountKopecks: 1200000,
      periodMonths: 1,
      nextDueAt: DateTime(2026, 10, 25),
      anchorDay: 25,
      remindDaysBefore: 1,
      endsAt: DateTime(2027, 3, 25),
      note: '',
      isActive: true,
    ),
    Payment(
      id: 4,
      name: 'Рассрочка',
      categoryId: 2,
      amountKopecks: 500000,
      periodMonths: 3,
      nextDueAt: DateTime(2026, 8, 10),
      anchorDay: 10,
      remindDaysBefore: 7,
      endsAt: DateTime(2026, 8, 10),
      note: 'выплачена',
      isActive: false,
    ),
  ],
  records: [
    PaymentRecord(
      id: 1,
      paymentId: 1,
      amountKopecks: 69000,
      paidAt: DateTime(2026, 9, 20, 18, 30),
    ),
    PaymentRecord(
      id: 2,
      paymentId: 4,
      amountKopecks: 500000,
      paidAt: DateTime(2026, 8, 10, 9),
    ),
  ],
);

void expectSameData(BackupData actual, BackupData expected) {
  _same(actual.categories, expected.categories, 'категории');
  _same(actual.payments, expected.payments, 'платежи');
  _same(actual.records, expected.records, 'оплаты');
}

void _same(List<Object> actual, List<Object> expected, String what) {
  if (actual.length != expected.length) {
    throw StateError(
      '$what: ${actual.length} вместо ${expected.length}\n$actual\n$expected',
    );
  }
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) {
      throw StateError(
        '$what №${i + 1} отличается:\n${actual[i]}\n${expected[i]}',
      );
    }
  }
}
