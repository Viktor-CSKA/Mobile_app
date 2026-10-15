import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/backup_codec.dart';

/// Чтение и полная замена всех данных приложения.
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  Future<BackupData> readAll() async {
    final categories = await (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
    final payments = await (_db.select(
      _db.payments,
    )..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
    final records = await (_db.select(
      _db.paymentRecords,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    return BackupData(
      categories: categories,
      payments: payments,
      records: records,
    );
  }

  /// Заменяет ВСЕ данные содержимым [data] одной транзакцией: при любой ошибке
  /// прежние данные остаются как были.
  Future<void> replaceAll(BackupData data) {
    return _db.transaction(() async {
      await _db.delete(_db.paymentRecords).go();
      await _db.delete(_db.payments).go();
      await _db.delete(_db.categories).go();

      await _db.batch((b) {
        b.insertAll(_db.categories, [
          for (final c in data.categories)
            CategoriesCompanion.insert(
              id: Value(c.id),
              name: c.name,
              colorValue: c.colorValue,
            ),
        ]);
        b.insertAll(_db.payments, [
          for (final p in data.payments)
            PaymentsCompanion.insert(
              id: Value(p.id),
              name: p.name,
              categoryId: p.categoryId,
              amountKopecks: Value(p.amountKopecks),
              periodMonths: Value(p.periodMonths),
              nextDueAt: p.nextDueAt,
              anchorDay: p.anchorDay,
              remindDaysBefore: Value(p.remindDaysBefore),
              endsAt: Value(p.endsAt),
              note: Value(p.note),
              isActive: Value(p.isActive),
            ),
        ]);
        b.insertAll(_db.paymentRecords, [
          for (final r in data.records)
            PaymentRecordsCompanion.insert(
              id: Value(r.id),
              paymentId: r.paymentId,
              amountKopecks: r.amountKopecks,
              paidAt: r.paidAt,
            ),
        ]);
      });
    });
  }
}
