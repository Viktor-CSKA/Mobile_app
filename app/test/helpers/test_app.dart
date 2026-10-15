import 'package:drift/native.dart';
import 'package:ezhemesyachno/app.dart';
import 'package:ezhemesyachno/core/clock.dart';
import 'package:ezhemesyachno/core/database/app_database.dart';
import 'package:ezhemesyachno/core/database/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Виджет-тест приложения с базой в памяти (вместо файла на устройстве).
///
/// После теста дерево виджетов снимается и время прокручивается: Drift при
/// закрытии подписок ставит нулевой таймер, а Flutter не терпит висящих таймеров.
///
/// [today] — фиксированная «сегодняшняя» дата для экранов, зависящих от даты.
/// [seed] — заполняет базу до запуска приложения.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, AppDatabase db) body, {
  DateTime? today,
  Future<void> Function(AppDatabase db)? seed,
}) {
  testWidgets(description, (tester) async {
    // Высокий экран, чтобы вся форма помещалась без прокрутки.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Открываем базу в настоящем времени: иначе первое обращение из
    // «фейковой» зоны виджет-теста блокирует запросы из runAsync.
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    // Данные кладём до запуска экранов: первый же запрос их увидит.
    if (seed != null) await tester.runAsync(() => seed(db));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          if (today != null) todayProvider.overrideWithValue(today),
        ],
        child: const EzhemesyachnoApp(),
      ),
    );
    await tester.pump();

    await body(tester, db);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
