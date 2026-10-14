import 'package:drift/native.dart';
import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/features/payments/data/payments_repository.dart';
import 'package:ezhemesyachno/features/payments/domain/payment_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PaymentsRepository repo;
  late int categoryId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = PaymentsRepository(db);
    categoryId = (await repo.watchCategories().first).first.id;
  });

  tearDown(() => db.close());

  PaymentDraft draft({
    String name = 'Интернет',
    int? amount = 69000,
    int period = 1,
    DateTime? due,
    DateTime? ends,
  }) => PaymentDraft(
    name: name,
    categoryId: categoryId,
    amountKopecks: amount,
    periodMonths: period,
    nextDueAt: due ?? DateTime(2026, 10, 15),
    endsAt: ends,
  );

  test('категории созданы при первом запуске', () async {
    final cats = await repo.watchCategories().first;
    expect(cats.length, 8);
    expect(cats.map((c) => c.name), contains('ЖКХ'));
  });

  group('add', () {
    test('сохраняет платёж с категорией и исходным днём', () async {
      final id = await repo.add(draft(due: DateTime(2026, 1, 31, 18, 30)));
      final list = await repo.watchActive().first;
      expect(list.length, 1);
      final p = list.single.payment;
      expect(p.id, id);
      expect(p.name, 'Интернет');
      expect(p.nextDueAt, DateTime(2026, 1, 31));
      expect(p.anchorDay, 31);
      expect(p.amountKopecks, 69000);
      expect(p.isActive, isTrue);
      expect(list.single.category.id, categoryId);
    });

    test('обрезает пробелы в названии', () async {
      await repo.add(draft(name: '  Яндекс Плюс  '));
      final p = (await repo.watchActive().first).single.payment;
      expect(p.name, 'Яндекс Плюс');
    });

    test('переменная сумма хранится как null', () async {
      await repo.add(draft(name: 'Электричество', amount: null));
      final p = (await repo.watchActive().first).single.payment;
      expect(p.amountKopecks, isNull);
    });

    test('список отсортирован по ближайшей дате', () async {
      await repo.add(draft(name: 'Позже', due: DateTime(2026, 10, 25)));
      await repo.add(draft(name: 'Раньше', due: DateTime(2026, 10, 5)));
      final names = (await repo.watchActive().first).map((e) => e.payment.name);
      expect(names, ['Раньше', 'Позже']);
    });

    test('отклоняет пустое название', () {
      expect(() => repo.add(draft(name: '   ')), throwsArgumentError);
    });

    test('отклоняет отрицательную сумму', () {
      expect(() => repo.add(draft(amount: -1)), throwsArgumentError);
    });

    test('отклоняет период меньше месяца', () {
      expect(() => repo.add(draft(period: 0)), throwsArgumentError);
    });

    test('отклоняет окончание раньше ближайшего платежа', () {
      expect(
        () => repo.add(
          draft(due: DateTime(2026, 10, 15), ends: DateTime(2026, 10, 14)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('update', () {
    test('меняет поля', () async {
      final id = await repo.add(draft());
      await repo.update(id, draft(name: 'Домашний интернет', amount: 75000));
      final p = (await repo.getById(id))!;
      expect(p.name, 'Домашний интернет');
      expect(p.amountKopecks, 75000);
    });

    test('исходный день не меняется, если дата не менялась', () async {
      final id = await repo.add(draft(due: DateTime(2026, 1, 31)));
      await repo.markPaid(id); // дата стала 28 февраля, исходный день 31
      final moved = (await repo.getById(id))!;
      expect(moved.nextDueAt, DateTime(2026, 2, 28));

      await repo.update(id, draft(name: 'Другое', due: moved.nextDueAt));
      expect((await repo.getById(id))!.anchorDay, 31);
    });

    test('новая дата задаёт новый исходный день', () async {
      final id = await repo.add(draft(due: DateTime(2026, 1, 31)));
      await repo.update(id, draft(due: DateTime(2026, 2, 10)));
      expect((await repo.getById(id))!.anchorDay, 10);
    });

    test('несуществующий платёж даёт ошибку', () {
      expect(() => repo.update(999, draft()), throwsStateError);
    });
  });

  group('markPaid', () {
    test('пишет оплату и двигает дату, сохраняя исходный день', () async {
      final id = await repo.add(draft(due: DateTime(2026, 1, 31)));

      await repo.markPaid(id, paidAt: DateTime(2026, 1, 30));
      expect((await repo.getById(id))!.nextDueAt, DateTime(2026, 2, 28));

      await repo.markPaid(id, paidAt: DateTime(2026, 2, 27));
      expect((await repo.getById(id))!.nextDueAt, DateTime(2026, 3, 31));

      final records = await repo.watchRecords(id).first;
      expect(records.length, 2);
      expect(records.first.amountKopecks, 69000);
    });

    test('переменная сумма: без суммы ошибка, с суммой записывается', () async {
      final id = await repo.add(draft(name: 'Вода', amount: null));
      expect(() => repo.markPaid(id), throwsArgumentError);

      await repo.markPaid(id, amountKopecks: 41250);
      final record = (await repo.watchRecords(id).first).single;
      expect(record.amountKopecks, 41250);
      expect((await repo.getById(id))!.nextDueAt, DateTime(2026, 11, 15));
    });

    test('последний платёж кредита делает его неактивным', () async {
      final id = await repo.add(
        draft(
          name: 'Рассрочка',
          due: DateTime(2026, 11, 10),
          ends: DateTime(2026, 11, 10),
        ),
      );
      await repo.markPaid(id);

      expect((await repo.getById(id))!.isActive, isFalse);
      expect(await repo.watchActive().first, isEmpty);
      expect((await repo.watchRecords(id).first).length, 1);
    });

    test('не двигает дату, если запись не удалась', () async {
      final id = await repo.add(draft(name: 'Вода', amount: null));
      await expectLater(repo.markPaid(id), throwsArgumentError);
      expect((await repo.getById(id))!.nextDueAt, DateTime(2026, 10, 15));
      expect(await repo.watchRecords(id).first, isEmpty);
    });

    test('несуществующий платёж даёт ошибку', () {
      expect(() => repo.markPaid(999), throwsStateError);
    });
  });

  test('delete удаляет платёж и его историю', () async {
    final id = await repo.add(draft());
    await repo.markPaid(id);
    await repo.delete(id);

    expect(await repo.getById(id), isNull);
    expect(await repo.watchActive().first, isEmpty);
    expect(await repo.watchRecords(id).first, isEmpty);
  });
}
