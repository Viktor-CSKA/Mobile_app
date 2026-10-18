import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/payment_draft.dart';
import '../domain/payment_schedule.dart';

/// Доступ к платежам в базе. Вся работа с датами идёт через [PaymentSchedule].
class PaymentsRepository {
  PaymentsRepository(this._db);

  final AppDatabase _db;

  /// Активные платежи по возрастанию ближайшей даты.
  Stream<List<PaymentWithCategory>> watchActive() {
    final query =
        _db.select(_db.payments).join([
            innerJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.payments.categoryId),
            ),
          ])
          ..where(_db.payments.isActive.equals(true))
          ..orderBy([
            OrderingTerm.asc(_db.payments.nextDueAt),
            OrderingTerm.asc(_db.payments.name),
          ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PaymentWithCategory(
            row.readTable(_db.payments),
            row.readTable(_db.categories),
          ),
      ],
    );
  }

  /// Платежи в архиве: выплаченные кредиты и убранные вручную. По названию.
  Stream<List<PaymentWithCategory>> watchArchived() {
    final query =
        _db.select(_db.payments).join([
            innerJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.payments.categoryId),
            ),
          ])
          ..where(_db.payments.isActive.equals(false))
          ..orderBy([OrderingTerm.asc(_db.payments.name)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PaymentWithCategory(
            row.readTable(_db.payments),
            row.readTable(_db.categories),
          ),
      ],
    );
  }

  /// Оплаты за период [from]..[to] включительно (по дню оплаты), в том числе
  /// по уже закрытым платежам. Старые по дате — первыми.
  Stream<List<PaidEntry>> watchPaidBetween(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    final endExclusive = DateTime(end.year, end.month, end.day + 1);
    final query =
        _db.select(_db.paymentRecords).join([
            innerJoin(
              _db.payments,
              _db.payments.id.equalsExp(_db.paymentRecords.paymentId),
            ),
            innerJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.payments.categoryId),
            ),
          ])
          ..where(
            _db.paymentRecords.paidAt.isBiggerOrEqualValue(start) &
                _db.paymentRecords.paidAt.isSmallerThanValue(endExclusive),
          )
          ..orderBy([OrderingTerm.asc(_db.paymentRecords.paidAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          PaidEntry(
            row.readTable(_db.paymentRecords),
            row.readTable(_db.payments),
            row.readTable(_db.categories),
          ),
      ],
    );
  }

  Stream<List<Category>> watchCategories() {
    return (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();
  }

  Future<Payment?> getById(int id) {
    return (_db.select(
      _db.payments,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Создаёт платёж; возвращает его id.
  Future<int> add(PaymentDraft draft) {
    _check(draft);
    final due = dateOnly(draft.nextDueAt);
    return _db
        .into(_db.payments)
        .insert(
          PaymentsCompanion.insert(
            name: draft.name.trim(),
            categoryId: draft.categoryId,
            nextDueAt: due,
            anchorDay: due.day,
            amountKopecks: Value(draft.amountKopecks),
            periodMonths: Value(draft.periodMonths),
            remindDaysBefore: Value(draft.remindDaysBefore),
            endsAt: Value(_endDate(draft)),
            note: Value(draft.note.trim()),
          ),
        );
  }

  /// Убирает платёж из списка, «Ближайших», календаря и напоминаний. История
  /// оплат остаётся (оплаты по-прежнему видны в календаре за свои месяцы).
  Future<void> archive(int id) async {
    final updated =
        await (_db.update(_db.payments)..where((p) => p.id.equals(id))).write(
          const PaymentsCompanion(isActive: Value(false)),
        );
    if (updated == 0) throw StateError('Платёж $id не найден');
  }

  /// Возвращает платёж из архива. Дату, которая уже прошла, сдвигает на
  /// ближайшую сегодняшнюю или будущую. Возвращает false и ничего не меняет,
  /// если срок платежа закончился (кредит выплачен): его нужно изменить через
  /// [update] с `reactivate: true`.
  Future<bool> unarchive(int id, {required DateTime today}) async {
    final payment = await getById(id);
    if (payment == null) throw StateError('Платёж $id не найден');
    var schedule = payment.schedule;
    while (schedule.isOverdue(today)) {
      final next = schedule.followingDue();
      if (next == null) return false;
      schedule = PaymentSchedule(
        nextDueAt: next,
        anchorDay: payment.anchorDay,
        periodMonths: payment.periodMonths,
        endsAt: payment.endsAt,
      );
    }
    await (_db.update(_db.payments)..where((p) => p.id.equals(id))).write(
      PaymentsCompanion(
        isActive: const Value(true),
        nextDueAt: Value(dateOnly(schedule.nextDueAt)),
      ),
    );
    return true;
  }

  /// Обновляет платёж. Если дата изменилась, исходный день берётся из новой.
  /// Платёж из архива остаётся в архиве, пока не передано `reactivate: true`.
  Future<void> update(
    int id,
    PaymentDraft draft, {
    bool reactivate = false,
  }) async {
    _check(draft);
    final existing = await getById(id);
    if (existing == null) throw StateError('Платёж $id не найден');
    final due = dateOnly(draft.nextDueAt);
    final dateChanged = due != dateOnly(existing.nextDueAt);
    await (_db.update(_db.payments)..where((p) => p.id.equals(id))).write(
      PaymentsCompanion(
        name: Value(draft.name.trim()),
        categoryId: Value(draft.categoryId),
        nextDueAt: Value(due),
        anchorDay: Value(dateChanged ? due.day : existing.anchorDay),
        amountKopecks: Value(draft.amountKopecks),
        periodMonths: Value(draft.periodMonths),
        remindDaysBefore: Value(draft.remindDaysBefore),
        endsAt: Value(_endDate(draft)),
        note: Value(draft.note.trim()),
        isActive: Value(reactivate || existing.isActive),
      ),
    );
  }

  /// Удаляет платёж вместе с историей оплат.
  Future<void> delete(int id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.paymentRecords,
      )..where((r) => r.paymentId.equals(id))).go();
      await (_db.delete(_db.payments)..where((p) => p.id.equals(id))).go();
    });
  }

  /// Отмечает платёж оплаченным: пишет в историю и двигает дату вперёд.
  /// Если платёж закончился (кредит выплачен), он становится неактивным.
  ///
  /// Для платежа с переменной суммой [amountKopecks] обязателен.
  /// Сумма может отличаться от обычной (фактически оплачено).
  ///
  /// Возвращает [PaidResult]: новую ближайшую дату (null, если платёж
  /// закончился) и данные для отмены через [undoPaid].
  Future<PaidResult> markPaid(int id, {int? amountKopecks, DateTime? paidAt}) {
    return _db.transaction(() async {
      final payment = await getById(id);
      if (payment == null) throw StateError('Платёж $id не найден');
      final amount = amountKopecks ?? payment.amountKopecks;
      if (amount == null) {
        throw ArgumentError('Для платежа с переменной суммой нужна сумма');
      }
      if (amount < 0) throw ArgumentError('Сумма не может быть отрицательной');

      final recordId = await _db
          .into(_db.paymentRecords)
          .insert(
            PaymentRecordsCompanion.insert(
              paymentId: id,
              amountKopecks: amount,
              paidAt: paidAt ?? DateTime.now(),
            ),
          );

      final next = payment.schedule.followingDue();
      await (_db.update(_db.payments)..where((p) => p.id.equals(id))).write(
        next == null
            ? const PaymentsCompanion(isActive: Value(false))
            : PaymentsCompanion(nextDueAt: Value(next)),
      );
      return PaidResult(
        recordId: recordId,
        paymentId: id,
        previousDue: payment.nextDueAt,
        wasActive: payment.isActive,
        nextDue: next,
      );
    });
  }

  /// Отменяет оплату: удаляет запись из истории и возвращает платёж в
  /// состояние до оплаты. Возвращает false и ничего не меняет, если запись уже
  /// удалена или платёж с тех пор изменили (чтобы не затереть правки).
  Future<bool> undoPaid(PaidResult paid) {
    return _db.transaction(() async {
      final record = await (_db.select(
        _db.paymentRecords,
      )..where((r) => r.id.equals(paid.recordId))).getSingleOrNull();
      final payment = await getById(paid.paymentId);
      if (record == null || payment == null) return false;

      final unchanged =
          payment.isActive == (paid.nextDue != null) &&
          dateOnly(payment.nextDueAt) ==
              dateOnly(paid.nextDue ?? paid.previousDue);
      if (!unchanged) return false;

      await (_db.delete(
        _db.paymentRecords,
      )..where((r) => r.id.equals(paid.recordId))).go();
      await (_db.update(
        _db.payments,
      )..where((p) => p.id.equals(paid.paymentId))).write(
        PaymentsCompanion(
          nextDueAt: Value(paid.previousDue),
          isActive: Value(paid.wasActive),
        ),
      );
      return true;
    });
  }

  Stream<List<PaymentRecord>> watchRecords(int paymentId) {
    return (_db.select(_db.paymentRecords)
          ..where((r) => r.paymentId.equals(paymentId))
          ..orderBy([(r) => OrderingTerm.desc(r.paidAt)]))
        .watch();
  }

  DateTime? _endDate(PaymentDraft draft) =>
      draft.endsAt == null ? null : dateOnly(draft.endsAt!);

  void _check(PaymentDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw ArgumentError('Название не может быть пустым');
    }
    if (draft.periodMonths < 1) {
      throw ArgumentError('Период должен быть не меньше 1 месяца');
    }
    if (draft.amountKopecks != null && draft.amountKopecks! < 0) {
      throw ArgumentError('Сумма не может быть отрицательной');
    }
    if (draft.endsAt != null &&
        dateOnly(draft.endsAt!).isBefore(dateOnly(draft.nextDueAt))) {
      throw ArgumentError('Дата окончания раньше ближайшего платежа');
    }
  }
}
