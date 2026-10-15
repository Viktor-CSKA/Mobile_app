import 'package:drift/native.dart';
import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/backup/data/backup_repository.dart';
import 'package:ezhemesyachno/features/backup/domain/backup_codec.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/backup_samples.dart';

void main() {
  late AppDatabase db;
  late BackupRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BackupRepository(db);
  });

  tearDown(() => db.close());

  test('новая база: категории по умолчанию, платежей и оплат нет', () async {
    final data = await repo.readAll();
    expect(data.categories.length, 8);
    expect(data.payments, isEmpty);
    expect(data.records, isEmpty);
  });

  test('replaceAll и readAll возвращают те же данные', () async {
    await repo.replaceAll(sampleData());
    expectSameData(await repo.readAll(), sampleData());
  });

  test('прежние данные полностью заменяются', () async {
    final payments = PaymentsRepository(db);
    final cat = (await payments.watchCategories().first).first.id;
    await payments.add(
      PaymentDraft(
        name: 'Старый платёж',
        categoryId: cat,
        amountKopecks: 100,
        nextDueAt: DateTime(2026, 1, 1),
      ),
    );

    await repo.replaceAll(sampleData());

    final data = await repo.readAll();
    expect(data.payments.map((p) => p.name), isNot(contains('Старый платёж')));
    expect(data.categories.length, 2); // стандартные категории тоже заменены
    expectSameData(data, sampleData());
  });

  test('номера сохраняются, новые записи получают следующие номера', () async {
    await repo.replaceAll(sampleData());
    final payments = PaymentsRepository(db);
    final newId = await payments.add(
      PaymentDraft(
        name: 'Новый',
        categoryId: 1,
        amountKopecks: 100,
        nextDueAt: DateTime(2026, 11, 1),
      ),
    );
    expect(newId, 5); // в копии были платежи 1..4
  });

  test('копия поверх копии даёт те же данные (идемпотентно)', () async {
    await repo.replaceAll(sampleData());
    await repo.replaceAll(sampleData());
    expectSameData(await repo.readAll(), sampleData());
  });

  test('пустая копия очищает данные', () async {
    await repo.replaceAll(sampleData());
    await repo.replaceAll(
      const BackupData(categories: [], payments: [], records: []),
    );
    final data = await repo.readAll();
    expect(data.categories, isEmpty);
    expect(data.payments, isEmpty);
    expect(data.records, isEmpty);
  });

  test(
    'при ошибке записи прежние данные остаются (откат транзакции)',
    () async {
      await repo.replaceAll(sampleData());
      final broken = BackupData(
        categories: const [
          kHousing,
          kHousing,
        ], // повтор номера → ошибка вставки
        payments: const [],
        records: const [],
      );

      await expectLater(repo.replaceAll(broken), throwsA(anything));

      expectSameData(await repo.readAll(), sampleData());
    },
  );

  test('читает данные, добавленные через обычный репозиторий', () async {
    final payments = PaymentsRepository(db);
    final cat = (await payments.watchCategories().first).first.id;
    final id = await payments.add(
      PaymentDraft(
        name: 'Вода',
        categoryId: cat,
        amountKopecks: null,
        nextDueAt: DateTime(2026, 10, 12),
      ),
    );
    await payments.markPaid(
      id,
      amountKopecks: 41250,
      paidAt: DateTime(2026, 10, 12, 20),
    );

    final data = await repo.readAll();
    expect(data.payments.single.name, 'Вода');
    expect(data.payments.single.amountKopecks, isNull);
    expect(data.records.single.amountKopecks, 41250);
  });
}
