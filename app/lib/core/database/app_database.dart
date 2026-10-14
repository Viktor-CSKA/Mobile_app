import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Категории платежей: ЖКХ, кредиты, подписки и т.д.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get colorValue => integer()();
}

/// Регулярный платёж. Суммы везде в копейках (int), без double.
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// null — сумма переменная (например, ЖКХ), вводится при оплате.
  IntColumn get amountKopecks => integer().nullable()();

  /// Период повтора в месяцах: 1 — ежемесячно, 3 — раз в квартал, 12 — раз в год.
  IntColumn get periodMonths => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDueAt => dateTime()();

  /// Исходный день месяца (1..31). Нужен, чтобы платёж «31-го» после февраля
  /// возвращался на 31-е, а не оставался на 28-м.
  IntColumn get anchorDay => integer()();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(1))();

  /// Дата окончания (кредит, рассрочка); null — бессрочно (подписка).
  DateTimeColumn get endsAt => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// История оплат: отметка «оплачено» двигает nextDueAt вперёд.
class PaymentRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get paymentId => integer().references(Payments, #id)();
  IntColumn get amountKopecks => integer()();
  DateTimeColumn get paidAt => dateTime()();
}

@DriftDatabase(tables: [Categories, Payments, PaymentRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'ezhemesyachno'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
    // Новые версии схемы: добавлять шаги `if (from < N)` и тест миграции.
    onUpgrade: (m, from, to) async {},
  );

  Future<void> _seedCategories() async {
    const defaults = <(String, int)>[
      ('ЖКХ', 0xFF795548),
      ('Кредиты и ипотека', 0xFFE53935),
      ('Рассрочки', 0xFFFB8C00),
      ('Подписки', 0xFF8E24AA),
      ('Связь и интернет', 0xFF1E88E5),
      ('Налоги и штрафы', 0xFF546E7A),
      ('Страховка', 0xFF43A047),
      ('Прочее', 0xFF757575),
    ];
    await batch((b) {
      b.insertAll(categories, [
        for (final (name, color) in defaults)
          CategoriesCompanion.insert(name: name, colorValue: color),
      ]);
    });
  }
}
