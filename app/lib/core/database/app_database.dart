import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Категории расходов. Суммы везде хранятся в копейках (int), без double.
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get colorValue => integer()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountKopecks => integer()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get spentAt => dateTime()();
}

class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get amountKopecks => integer()();
  IntColumn get periodMonths => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextChargeAt => dateTime()();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DriftDatabase(tables: [Categories, Expenses, Subscriptions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'expense_tracker'));

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
      ('Продукты', 0xFF4CAF50),
      ('Транспорт', 0xFF2196F3),
      ('Дом и ЖКХ', 0xFF795548),
      ('Здоровье', 0xFFE91E63),
      ('Развлечения', 0xFF9C27B0),
      ('Подписки', 0xFFFF9800),
      ('Прочее', 0xFF607D8B),
    ];
    await batch((b) {
      b.insertAll(categories, [
        for (final (name, color) in defaults)
          CategoriesCompanion.insert(name: name, colorValue: color),
      ]);
    });
  }
}
